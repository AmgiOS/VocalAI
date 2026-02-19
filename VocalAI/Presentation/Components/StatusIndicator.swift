import SwiftUI

/// Displays the current conversation state as a pill-shaped label.
struct StatusIndicator: View {
    let state: ConversationState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .listening:
            Label("Listening...", systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.15), in: Capsule())
        case .thinking:
            Label("Thinking...", systemImage: "brain")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.15), in: Capsule())
        case .speaking:
            Label("Speaking...", systemImage: "speaker.wave.2")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.15), in: Capsule())
        }
    }
}

#Preview("Status Indicators") {
    VStack(spacing: 16) {
        StatusIndicator(state: .idle)
        StatusIndicator(state: .listening)
        StatusIndicator(state: .thinking)
        StatusIndicator(state: .speaking)
    }
    .padding()
}
