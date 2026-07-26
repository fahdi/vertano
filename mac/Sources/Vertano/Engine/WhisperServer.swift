import Foundation

/// A persistent `whisper-server` (from whisper.cpp) that keeps the model
/// resident across live-transcription chunks, so each chunk no longer pays
/// the cold-start cost of reloading a 0.5-1.6 GB model from disk.
///
/// The pure request/response/argument helpers are unit-tested; `start()` /
/// `transcribe(_:)` / `stop()` are the thin process + HTTP glue that compose
/// them. When the `whisper-server` binary is absent, callers fall back to the
/// per-chunk `whisper-cli` path.
final class WhisperServer: @unchecked Sendable {
    enum ServerError: LocalizedError {
        case binaryNotFound
        case malformedResponse
        case notRunning
        case startupTimedOut

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "whisper-server not found. Install with: brew install whisper-cpp"
            case .malformedResponse:
                return "whisper-server returned an unexpected response."
            case .notRunning:
                return "whisper-server is not running."
            case .startupTimedOut:
                return "whisper-server did not become ready in time."
            }
        }
    }

    // MARK: - Pure helpers (unit-tested)

    static var binaryPath: String? { WhisperEngine.findBinary("whisper-server") }

    /// Argument vector to launch the server with the model resident.
    /// `extraFlags` carries the latency/GPU flags (threads, flash-attn, etc.).
    static func launchArguments(
        modelPath: String, host: String, port: Int, extraFlags: [String]
    ) -> [String] {
        ["-m", modelPath, "--host", host, "--port", String(port)] + extraFlags
    }

    static func inferenceURL(host: String, port: Int) -> URL {
        URL(string: "http://\(host):\(port)/inference")!
    }

    /// Extract the transcript from whisper-server's JSON response, trimmed and
    /// with whisper's silence marker stripped (a silent chunk is normal).
    static func parseInference(_ data: Data) throws -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = object["text"] as? String
        else {
            throw ServerError.malformedResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Lifecycle

    private let host = "127.0.0.1"
    private let port: Int
    private let process = Process()
    private let session = URLSession(configuration: .ephemeral)

    private(set) var isRunning = false

    init(port: Int = 8181) {
        self.port = port
    }

    /// Boots the server with the model resident and blocks until it answers
    /// (or `timeout` elapses). Throws `.binaryNotFound` when whisper-server is
    /// not installed so the caller can fall back to the CLI path.
    func start(modelPath: String, extraFlags: [String], timeout: TimeInterval = 15) async throws {
        guard let binary = Self.binaryPath else { throw ServerError.binaryNotFound }

        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Self.launchArguments(
            modelPath: modelPath, host: host, port: port, extraFlags: extraFlags)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await isHealthy() {
                isRunning = true
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        stop()
        throw ServerError.startupTimedOut
    }

    func transcribe(wav: Data, language: String, translateToEnglish: Bool) async throws -> String {
        guard isRunning else { throw ServerError.notRunning }
        let request = Self.inferenceRequest(
            host: host, port: port, wav: wav,
            language: language, translateToEnglish: translateToEnglish)
        let (data, _) = try await session.data(for: request)
        return try Self.parseInference(data)
    }

    func stop() {
        isRunning = false
        if process.isRunning { process.terminate() }
    }

    private func isHealthy() async -> Bool {
        var request = URLRequest(url: URL(string: "http://\(host):\(port)/")!)
        request.timeoutInterval = 1
        return (try? await session.data(for: request)) != nil
    }

    /// Builds the multipart/form-data POST that whisper-server's `/inference`
    /// endpoint expects. Kept static so the body encoding is unit-testable.
    static func inferenceRequest(
        host: String, port: Int, wav: Data,
        language: String, translateToEnglish: Bool
    ) -> URLRequest {
        let boundary = "vertano.\(UUID().uuidString)"
        var request = URLRequest(url: inferenceURL(host: host, port: port))
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary, wav: wav,
            language: language, translateToEnglish: translateToEnglish)
        return request
    }

    static func multipartBody(
        boundary: String, wav: Data, language: String, translateToEnglish: Bool
    ) -> Data {
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"\r\n"
                .data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wav)
        body.append("\r\n".data(using: .utf8)!)
        field("response_format", "json")
        field("language", language)
        field("translate", translateToEnglish ? "true" : "false")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
