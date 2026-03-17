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
    return URLSession(configuration: config, delegate: downloadSessionDelegate, delegateQueue: nil)
}()

@Observable
@MainActor
final class AdhanAudioDownloadManager {
    var downloadStates: [String: DownloadState] = [:]
    private var activeTasks: [String: Task<Void, Never>] = [:]

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
        // Don't restart if already downloading or downloaded
        if case .downloading = downloadStates[file.id] { return }
        if case .downloaded = downloadStates[file.id] { return }

        downloadStates[file.id] = .downloading(progress: 0)

        let task = Task { [weak self] in
            var lastError: Error?
            let maxAttempts = 3

            for attempt in 0..<maxAttempts {
                if attempt > 0 {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        self?.downloadStates[file.id] = .downloading(progress: 0)
                    }
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
                                        self?.downloadStates[file.id] = .downloading(progress: progress)
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

                    await MainActor.run {
                        self?.downloadStates[file.id] = .downloaded
                        self?.activeTasks.removeValue(forKey: file.id)
                    }
                    return // Success — exit retry loop
                } catch is CancellationError {
                    await MainActor.run {
                        self?.downloadStates[file.id] = .notDownloaded
                        self?.activeTasks.removeValue(forKey: file.id)
                    }
                    return
                } catch let error as URLError where error.code == .cancelled {
                    await MainActor.run {
                        self?.downloadStates[file.id] = .notDownloaded
                        self?.activeTasks.removeValue(forKey: file.id)
                    }
                    return
                } catch {
                    lastError = error
                }
            }

            // All retries exhausted
            await MainActor.run {
                self?.downloadStates[file.id] = .failed(message: lastError?.localizedDescription ?? "Download failed")
                self?.activeTasks.removeValue(forKey: file.id)
            }
        }

        activeTasks[file.id] = task
    }

    func cancelDownload(_ file: AdhanAudioFile) {
        activeTasks[file.id]?.cancel()
        activeTasks.removeValue(forKey: file.id)
        downloadStates[file.id] = .notDownloaded
    }

    func state(for id: String) -> DownloadState {
        downloadStates[id] ?? .notDownloaded
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

    func register(
        taskID: Int,
        progress: @escaping @Sendable (Double) -> Void,
        continuation: CheckedContinuation<URL, Error>
    ) {
        lock.lock()
        progressHandlers[taskID] = progress
        completionHandlers[taskID] = continuation
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
        let handler = progressHandlers[downloadTask.taskIdentifier]
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
            lock.unlock()
            continuation?.resume(returning: tempCopy)
        } catch {
            lock.lock()
            let continuation = completionHandlers.removeValue(forKey: downloadTask.taskIdentifier)
            progressHandlers.removeValue(forKey: downloadTask.taskIdentifier)
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
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
