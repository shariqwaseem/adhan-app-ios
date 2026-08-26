import Foundation
import Observation

enum DownloadState: Sendable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(message: String)
}

// MARK: - Module-level download session with progress delegate

private let downloadSessionDelegate = DownloadSessionDelegate()

private let downloadSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 300
    config.httpMaximumConnectionsPerHost = 2
    return URLSession(configuration: config, delegate: downloadSessionDelegate, delegateQueue: nil)
}()

struct DownloadWorkQueue<Element: Hashable> {
    let maximumConcurrentCount: Int
    private(set) var pending: [Element] = []
    private(set) var active: Set<Element> = []

    init(maximumConcurrentCount: Int) {
        precondition(maximumConcurrentCount > 0)
        self.maximumConcurrentCount = maximumConcurrentCount
    }

    func contains(_ element: Element) -> Bool {
        active.contains(element) || pending.contains(element)
    }

    mutating func enqueue(_ element: Element) -> [Element] {
        guard !contains(element) else { return [] }
        pending.append(element)
        return claimAvailableWork()
    }

    mutating func complete(_ element: Element) -> [Element] {
        active.remove(element)
        return claimAvailableWork()
    }

    @discardableResult
    mutating func removePending(_ element: Element) -> Bool {
        guard let index = pending.firstIndex(of: element) else { return false }
        pending.remove(at: index)
        return true
    }

    private mutating func claimAvailableWork() -> [Element] {
        var claimed: [Element] = []
        while active.count < maximumConcurrentCount, !pending.isEmpty {
            let element = pending.removeFirst()
            active.insert(element)
            claimed.append(element)
        }
        return claimed
    }
}

struct DownloadProgressThrottler {
    let minimumInterval: TimeInterval
    private var lastEmissionTimeByTaskID: [Int: TimeInterval] = [:]

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    mutating func reset(taskID: Int) {
        lastEmissionTimeByTaskID.removeValue(forKey: taskID)
    }

    mutating func shouldEmit(taskID: Int, progress: Double, at time: TimeInterval) -> Bool {
        let shouldEmit = progress >= 1
            || lastEmissionTimeByTaskID[taskID] == nil
            || time - (lastEmissionTimeByTaskID[taskID] ?? time) >= minimumInterval

        if shouldEmit {
            lastEmissionTimeByTaskID[taskID] = time
        }
        return shouldEmit
    }
}

@Observable
@MainActor
final class AdhanAudioDownloadManager {
    var downloadStates: [String: DownloadState] = [:]
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var workQueue = DownloadWorkQueue<AdhanAudioFile>(maximumConcurrentCount: 2)

    private var soundsDirectoryURL: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryDir.appendingPathComponent("Sounds")
    }

    init() {
        ensureSoundsDirectory()
        syncDownloadStates()
    }

    // MARK: - Download

    func download(_ file: AdhanAudioFile) {
        // Don't restart if already queued, downloading, or downloaded.
        guard !workQueue.contains(file) else { return }
        if case .downloaded = downloadStates[file.id] { return }

        downloadStates[file.id] = .downloading(progress: 0)
        startDownloads(workQueue.enqueue(file))
    }

    func cancelDownload(_ file: AdhanAudioFile) {
        if workQueue.removePending(file) {
            downloadStates[file.id] = .notDownloaded
            return
        }

        guard workQueue.active.contains(file) else {
            downloadStates[file.id] = .notDownloaded
            return
        }

        // Keep the slot occupied until URLSession confirms cancellation. This prevents
        // a rapid cancel/restart sequence from exceeding the concurrency limit.
        activeTasks[file.id]?.cancel()
        downloadStates[file.id] = .notDownloaded
    }

    func state(for id: String) -> DownloadState {
        downloadStates[id] ?? .notDownloaded
    }

    private func startDownloads(_ files: [AdhanAudioFile]) {
        for file in files {
            let task = Task { [weak self] in
                guard let self else { return }
                await self.performDownload(file)
            }
            activeTasks[file.id] = task
        }
    }

    private func performDownload(_ file: AdhanAudioFile) async {
        var lastError: Error?
        let maxAttempts = 3

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    finishDownload(file, state: .notDownloaded)
                    return
                }
                downloadStates[file.id] = .downloading(progress: 0)
            }

            do {
                try Task.checkCancellation()

                let downloadTask = downloadSession.downloadTask(with: file.downloadURL)

                let tempURL: URL = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        downloadSessionDelegate.register(
                            taskID: downloadTask.taskIdentifier,
                            progress: { [weak self] progress in
                                Task { @MainActor in
                                    guard let self,
                                          self.workQueue.active.contains(file),
                                          self.activeTasks[file.id]?.isCancelled == false else { return }
                                    self.downloadStates[file.id] = .downloading(progress: progress)
                                }
                            },
                            continuation: continuation
                        )
                        downloadTask.resume()
                    }
                } onCancel: {
                    downloadTask.cancel()
                }

                if let http = downloadTask.response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    try? FileManager.default.removeItem(at: tempURL)
                    throw URLError(.badServerResponse)
                }

                try Task.checkCancellation()

                let destinationURL = file.localFileURL
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                finishDownload(file, state: .downloaded)
                return
            } catch is CancellationError {
                finishDownload(file, state: .notDownloaded)
                return
            } catch let error as URLError where error.code == .cancelled {
                finishDownload(file, state: .notDownloaded)
                return
            } catch {
                lastError = error
            }
        }

        finishDownload(
            file,
            state: .failed(message: lastError?.localizedDescription ?? "Download failed")
        )
    }

    private func finishDownload(_ file: AdhanAudioFile, state: DownloadState) {
        downloadStates[file.id] = state
        activeTasks.removeValue(forKey: file.id)
        startDownloads(workQueue.complete(file))
    }

    // MARK: - State Sync

    func syncDownloadStates() {
        for file in AdhanAudioCatalog.allFiles {
            if file.isDownloaded {
                downloadStates[file.id] = .downloaded
            } else if downloadStates[file.id] == nil {
                downloadStates[file.id] = .notDownloaded
            }
        }
    }

    /// Returns IDs of files referenced in preferences but missing from disk.
    func verifyDownloadedSounds() -> [String] {
        AdhanAudioCatalog.allFiles
            .filter { !$0.isDownloaded }
            .map { $0.id }
    }

    // MARK: - Private

    private func ensureSoundsDirectory() {
        let url = soundsDirectoryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Session-level download delegate for progress tracking

private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var progressHandlers: [Int: @Sendable (Double) -> Void] = [:]
    private var completionHandlers: [Int: CheckedContinuation<URL, Error>] = [:]
    private var progressThrottler = DownloadProgressThrottler(minimumInterval: 0.1)

    func register(
        taskID: Int,
        progress: @escaping @Sendable (Double) -> Void,
        continuation: CheckedContinuation<URL, Error>
    ) {
        lock.lock()
        progressHandlers[taskID] = progress
        completionHandlers[taskID] = continuation
        progressThrottler.reset(taskID: taskID)
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1.0)
        lock.lock()
        let taskID = downloadTask.taskIdentifier
        let shouldEmit = progressThrottler.shouldEmit(
            taskID: taskID,
            progress: progress,
            at: ProcessInfo.processInfo.systemUptime
        )
        let handler = shouldEmit ? progressHandlers[taskID] : nil
        lock.unlock()
        handler?(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Must copy before returning — the system deletes the temp file after this method returns
        let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try FileManager.default.copyItem(at: location, to: tempCopy)
            lock.lock()
            let continuation = completionHandlers.removeValue(forKey: downloadTask.taskIdentifier)
            progressHandlers.removeValue(forKey: downloadTask.taskIdentifier)
            progressThrottler.reset(taskID: downloadTask.taskIdentifier)
            lock.unlock()
            continuation?.resume(returning: tempCopy)
        } catch {
            lock.lock()
            let continuation = completionHandlers.removeValue(forKey: downloadTask.taskIdentifier)
            progressHandlers.removeValue(forKey: downloadTask.taskIdentifier)
            progressThrottler.reset(taskID: downloadTask.taskIdentifier)
            lock.unlock()
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return } // Success handled in didFinishDownloadingTo
        lock.lock()
        let continuation = completionHandlers.removeValue(forKey: task.taskIdentifier)
        progressHandlers.removeValue(forKey: task.taskIdentifier)
        progressThrottler.reset(taskID: task.taskIdentifier)
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
