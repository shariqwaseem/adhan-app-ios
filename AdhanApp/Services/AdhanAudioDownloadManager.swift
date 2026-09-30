import Foundation
import Observation

enum DownloadState: Sendable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(message: String)
}

// MARK: - Module-level download session with progress delegate

private let downloadSessionIdentifier = "com.shariq.adhanapp.audio-downloads"

private let downloadSessionDelegate = DownloadSessionDelegate()

/// Background session so downloads keep running (and complete) while the app is
/// suspended or terminated, instead of dropping the connection and restarting.
private let downloadSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: downloadSessionIdentifier)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.timeoutIntervalForResource = 3600
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
    /// Single instance: the background URLSession and its in-flight tasks are process-wide,
    /// so a second manager would re-adopt and steal the first one's tasks.
    static let shared = AdhanAudioDownloadManager()

    var downloadStates: [String: DownloadState] = [:]
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var workQueue = DownloadWorkQueue<AdhanAudioFile>(maximumConcurrentCount: 2)

    private var soundsDirectoryURL: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryDir.appendingPathComponent("Sounds")
    }

    private init() {
        ensureSoundsDirectory()
        installBundledSounds()
        syncDownloadStates()
        downloadSessionDelegate.onUnclaimedDownloadFinished = { [weak self] in
            Task { @MainActor in self?.syncDownloadStates() }
        }
        Task { await adoptInFlightDownloads() }
    }

    /// Called from the app delegate when iOS relaunches the app for background download events.
    nonisolated static func handleBackgroundSessionEvents(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        guard identifier == downloadSessionIdentifier else { return }
        downloadSessionDelegate.backgroundEventsCompletionHandler = completionHandler
        _ = downloadSession // Reconnect to the session so pending events are delivered.
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

    /// Re-attaches to downloads still running in the background session from a previous
    /// app process, so they continue instead of being restarted.
    private func adoptInFlightDownloads() async {
        let tasks = await downloadSession.allTasks
        for case let task as URLSessionDownloadTask in tasks {
            guard task.state == .running || task.state == .suspended,
                  let id = task.taskDescription,
                  let file = AdhanAudioCatalog.file(forID: id) else {
                task.cancel()
                continue
            }
            // Already started by this process (tapped before this lookup returned).
            if workQueue.contains(file) { continue }
            guard !file.isDownloaded else {
                task.cancel()
                continue
            }
            guard workQueue.enqueue(file) == [file] else {
                workQueue.removePending(file)
                task.cancel()
                continue
            }
            let expected = task.countOfBytesExpectedToReceive
            let progress = expected > 0 ? Double(task.countOfBytesReceived) / Double(expected) : 0
            downloadStates[file.id] = .downloading(progress: progress)
            startDownloads([file], existingTask: task)
        }
    }

    private func startDownloads(_ files: [AdhanAudioFile], existingTask: URLSessionDownloadTask? = nil) {
        for file in files {
            let task = Task { [weak self] in
                guard let self else { return }
                await self.performDownload(file, existingTask: existingTask)
            }
            activeTasks[file.id] = task
        }
    }

    private func performDownload(_ file: AdhanAudioFile, existingTask: URLSessionDownloadTask? = nil) async {
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
            }

            do {
                try Task.checkCancellation()

                // Resume from where the failed attempt stopped when the server allows it.
                let resumeData = (lastError as? URLError)?.downloadTaskResumeData
                let downloadTask: URLSessionDownloadTask
                if attempt == 0, let existingTask {
                    downloadTask = existingTask
                } else if let resumeData {
                    downloadTask = downloadSession.downloadTask(withResumeData: resumeData)
                } else {
                    downloadStates[file.id] = .downloading(progress: 0)
                    downloadTask = downloadSession.downloadTask(with: file.downloadURL)
                }
                downloadTask.taskDescription = file.id

                try await withTaskCancellationHandler {
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

                // The delegate has already moved the file into place; honour a late cancel.
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: file.localFileURL)
                    throw CancellationError()
                }

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

    /// Copies the bundled adhan into Library/Sounds so it behaves like a downloaded file
    /// (AlarmKit lookup, preview playback, download state).
    private func installBundledSounds() {
        guard let file = AdhanAudioCatalog.file(forID: AdhanAudioCatalog.bundledID),
              !file.isDownloaded,
              let bundledURL = Bundle.main.url(forResource: file.id, withExtension: "caf") else { return }
        try? FileManager.default.copyItem(at: bundledURL, to: file.localFileURL)
    }

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
    private var completionHandlers: [Int: CheckedContinuation<Void, Error>] = [:]
    /// Results of tasks that finished before anyone registered for them (e.g. adopted tasks).
    private var unclaimedResults: [Int: Result<Void, Error>] = [:]
    private var progressThrottler = DownloadProgressThrottler(minimumInterval: 0.1)
    private var _backgroundEventsCompletionHandler: (@Sendable () -> Void)?
    private var _onUnclaimedDownloadFinished: (@Sendable () -> Void)?

    var backgroundEventsCompletionHandler: (@Sendable () -> Void)? {
        get { lock.withLock { _backgroundEventsCompletionHandler } }
        set { lock.withLock { _backgroundEventsCompletionHandler = newValue } }
    }

    var onUnclaimedDownloadFinished: (@Sendable () -> Void)? {
        get { lock.withLock { _onUnclaimedDownloadFinished } }
        set { lock.withLock { _onUnclaimedDownloadFinished = newValue } }
    }

    func register(
        taskID: Int,
        progress: @escaping @Sendable (Double) -> Void,
        continuation: CheckedContinuation<Void, Error>
    ) {
        lock.lock()
        if let result = unclaimedResults.removeValue(forKey: taskID) {
            lock.unlock()
            continuation.resume(with: result)
            return
        }
        progressHandlers[taskID] = progress
        completionHandlers[taskID] = continuation
        progressThrottler.reset(taskID: taskID)
        lock.unlock()
    }

    private func complete(taskID: Int, with result: Result<Void, Error>) {
        lock.lock()
        let continuation = completionHandlers.removeValue(forKey: taskID)
        progressHandlers.removeValue(forKey: taskID)
        progressThrottler.reset(taskID: taskID)
        if continuation == nil {
            unclaimedResults[taskID] = result
        }
        let onUnclaimed = continuation == nil ? _onUnclaimedDownloadFinished : nil
        lock.unlock()
        continuation?.resume(with: result)
        onUnclaimed?()
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
        // Move into Library/Sounds here, before returning — the system deletes the temp file
        // afterwards, and the app may have been relaunched with no one awaiting this task.
        let result: Result<Void, Error>
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            result = .failure(URLError(.badServerResponse))
        } else if let id = downloadTask.taskDescription,
                  let file = AdhanAudioCatalog.file(forID: id) {
            result = Result {
                try? FileManager.default.removeItem(at: file.localFileURL)
                try FileManager.default.moveItem(at: location, to: file.localFileURL)
            }
        } else {
            result = .failure(URLError(.fileDoesNotExist))
        }
        complete(taskID: downloadTask.taskIdentifier, with: result)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return } // Success handled in didFinishDownloadingTo
        complete(taskID: task.taskIdentifier, with: .failure(error))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let handler = backgroundEventsCompletionHandler else { return }
        backgroundEventsCompletionHandler = nil
        DispatchQueue.main.async { handler() }
    }
}
