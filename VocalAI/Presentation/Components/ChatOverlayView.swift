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

#Preview("Chat - Conversation") {
    ChatOverlayView(
        messages: PreviewData.sampleMessages,
        partialTranscript: "",
        currentResponse: "",
        state: .idle
    )
    .frame(maxHeight: 200)
    .padding()
    .background(Color.black)
}

#Preview("Chat - Listening") {
    ChatOverlayView(
        messages: PreviewData.singleUserMessage,
        partialTranscript: "I was wondering about...",
        currentResponse: "",
        state: .listening
    )
    .frame(maxHeight: 200)
    .padding()
    .background(Color.black)
}

#Preview("Chat - Thinking") {
    ChatOverlayView(
        messages: PreviewData.sampleMessages,
        partialTranscript: "",
        currentResponse: "Sure! Let me think about that...",
        state: .thinking
    )
    .frame(maxHeight: 200)
    .padding()
    .background(Color.black)
}
