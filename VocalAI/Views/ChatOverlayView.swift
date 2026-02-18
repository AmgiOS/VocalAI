import SwiftUI

/// Semi-transparent overlay showing conversation transcript.
struct ChatOverlayView: View {
    let messages: [ConversationMessage]
    let partialTranscript: String
    let currentResponse: String
    let state: ConversationState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Show partial transcript while listening
                    if state == .listening, !partialTranscript.isEmpty {
                        MessageBubble(
                            message: ConversationMessage(role: .user, content: partialTranscript)
                        )
                        .opacity(0.6)
                        .id("partial")
                    }

                    // Show streaming response while thinking
                    if state == .thinking || state == .speaking, !currentResponse.isEmpty {
                        MessageBubble(
                            message: ConversationMessage(role: .assistant, content: currentResponse)
                        )
                        .id("response")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: currentResponse) {
                withAnimation {
                    proxy.scrollTo("response", anchor: .bottom)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.6))
        )
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
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
