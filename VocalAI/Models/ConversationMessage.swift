import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ConversationMessage: Identifiable, Sendable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(role: MessageRole, content: String, timestamp: Date = .now) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
