import Foundation

/// Sample data for SwiftUI previews.
enum PreviewData {
    static let sampleMessages: [ConversationMessage] = [
        ConversationMessage(role: .user, content: "Hello! Tell me about yourself."),
        ConversationMessage(role: .assistant, content: "Hi there! I'm a friendly AI assistant. I'm here to chat with you about anything you'd like."),
        ConversationMessage(role: .user, content: "What can you help me with?"),
        ConversationMessage(role: .assistant, content: "I can help with conversations, answer questions, or just have a friendly chat. What's on your mind?"),
    ]

    static let singleUserMessage: [ConversationMessage] = [
        ConversationMessage(role: .user, content: "Hello!"),
    ]

    static let emptyMessages: [ConversationMessage] = []

    static let longConversation: [ConversationMessage] = [
        ConversationMessage(role: .user, content: "Hi!"),
        ConversationMessage(role: .assistant, content: "Hello! Welcome! How are you doing today?"),
        ConversationMessage(role: .user, content: "I'm great, thanks! I was wondering about something."),
        ConversationMessage(role: .assistant, content: "Of course! I'm all ears. What's on your mind?"),
        ConversationMessage(role: .user, content: "Can you explain how emotions work in this app?"),
        ConversationMessage(role: .assistant, content: "Sure! The app analyzes the text of my responses to detect emotions like happiness, sadness, surprise, and more. Then my 3D avatar changes its facial expression to match!"),
        ConversationMessage(role: .user, content: "That's amazing!"),
        ConversationMessage(role: .assistant, content: "Thank you! I really enjoy our conversations. Is there anything else you'd like to know?"),
    ]
}
