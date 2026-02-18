import Foundation

/// Streaming HTTP client for the Claude API using URLSession.bytes.
actor ClaudeService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Streaming Chat

    /// Send a conversation to Claude and stream the response text.
    /// Yields partial text chunks as they arrive.
    func streamChat(
        messages: [ConversationMessage],
        systemPrompt: String = Configuration.systemPrompt,
        model: String = Configuration.claudeModel
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(messages: messages, systemPrompt: systemPrompt, model: model)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ClaudeError.invalidResponse
                    }

                    guard httpResponse.statusCode == 200 else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                        }
                        throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: body)
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))

                            if jsonStr == "[DONE]" { break }

                            if let data = jsonStr.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {
                                if let text = event.extractText() {
                                    continuation.yield(text)
                                }
                                if event.type == "message_stop" {
                                    break
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Request Building

    private func buildRequest(messages: [ConversationMessage], systemPrompt: String, model: String) throws -> URLRequest {
        guard !Configuration.claudeAPIKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Configuration.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let apiMessages = messages.filter { $0.role != .system }.map { msg in
            APIMessage(role: msg.role.rawValue, content: msg.content)
        }

        let body = RequestBody(
            model: model,
            max_tokens: 1024,
            system: systemPrompt,
            messages: apiMessages,
            stream: true
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}

// MARK: - API Types

extension ClaudeService {
    struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [APIMessage]
        let stream: Bool
    }

    struct APIMessage: Encodable {
        let role: String
        let content: String
    }

    struct StreamEvent: Decodable {
        let type: String
        let index: Int?
        let delta: Delta?
        let content_block: ContentBlock?

        struct Delta: Decodable {
            let type: String?
            let text: String?
        }

        struct ContentBlock: Decodable {
            let type: String?
            let text: String?
        }

        func extractText() -> String? {
            if type == "content_block_delta", let text = delta?.text {
                return text
            }
            return nil
        }
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is not configured."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .apiError(let code, let message):
            return "Claude API error (\(code)): \(message)"
        }
    }
}
