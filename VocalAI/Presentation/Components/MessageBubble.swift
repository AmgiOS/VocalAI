import SwiftUI

/// A single message bubble for the chat overlay.
struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.role == .user
                              ? Color.blue.opacity(0.7)
                              : Color.gray.opacity(0.2))
                )

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview("Message Bubbles") {
    VStack(spacing: 8) {
        MessageBubble(message: ConversationMessage(role: .user, content: "Hello! Tell me about yourself."))
        MessageBubble(message: ConversationMessage(role: .assistant, content: "Hi there! I'm a friendly AI assistant."))
        MessageBubble(message: ConversationMessage(role: .user, content: "That's great!"))
    }
    .padding()
}
