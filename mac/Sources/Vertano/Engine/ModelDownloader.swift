import Foundation

@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var error: String?
    /// The model currently downloading, if any — nil when idle.
    @Published private(set) var downloadingModel: WhisperModel?

    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    /// Pure validation shared by the download delegate and tests: a
    /// non-200 status or an undersized body (error page, truncated
    /// transfer) both need to fail before the file is trusted.
    nonisolated static func validate(status: Int, size: Int64, minimumValidSize: Int64) -> String? {
        if status != 200 {
            return "Download failed (HTTP \(status)). Try again."
        }
        if size < minimumValidSize {
            let mb = minimumValidSize / 1_000_000
            return "Download incomplete (\(size / 1_000_000) MB of ~\(mb) MB). "
                + "Check your connection and try again."
        }
        return nil
    }

    nonisolated static func validate(status: Int, size: Int64, model: WhisperModel) -> String? {
        validate(status: status, size: size, minimumValidSize: model.minimumValidSize)
    }

    nonisolated static func validate(status: Int, size: Int64, tier: ModelTier) -> String? {
        validate(status: status, size: size, minimumValidSize: tier.minimumValidSize)
    }

    func start(tier: ModelTier = .default) { start(model: tier.model) }

    func start(model: WhisperModel) {
        guard !isDownloading else { return }
        error = nil
        progress = 0
        isDownloading = true
        downloadingModel = model
        try? FileManager.default.createDirectory(
            at: WhisperEngine.modelsDirectory, withIntermediateDirectories: true)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: model.downloadURL)
        // Stashed on the task (thread-safe, no MainActor hop needed) so the
        // nonisolated delegate callback can recover which model this is
        // without touching MainActor-isolated state before the temp file at
        // `location` is deleted.
        task.taskDescription = model.filename
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
        isDownloading = false
        tearDownSession()
    }

    /// URLSession retains its delegate until invalidated; without this the
    /// downloader (and the session's queue) leak for the app's lifetime.
    private func tearDownSession() {
        session?.finishTasksAndInvalidate()
        session = nil
    }

    private func finish(errorMessage: String?) {
        isDownloading = false
        downloadingModel = nil
        progress = errorMessage == nil ? 1 : 0
        error = errorMessage
        task = nil
        tearDownSession()
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.progress = fraction }
    }

    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Validate before moving: a 404/500 body or captive-portal page also
        // lands here "successfully". Work synchronously — `location` is
        // deleted when this method returns.
        let model = WhisperModel.named(downloadTask.taskDescription ?? "") ?? ModelTier.default.model
        var failure: String?
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        let attrs = try? FileManager.default.attributesOfItem(atPath: location.path)
        let size = (attrs?[.size] as? Int64) ?? 0

        if let message = Self.validate(status: status, size: size, model: model) {
            failure = message
        } else {
            do {
                let dest = WhisperEngine.modelPath(for: model)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: location, to: dest)
            } catch {
                failure = error.localizedDescription
            }
        }

        let message = failure
        Task { @MainActor in self.finish(errorMessage: message) }
    }

    nonisolated func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
        let message = error.localizedDescription
        Task { @MainActor in self.finish(errorMessage: message) }
    }
}
