import SwiftUI

/// Animated microphone button with press-and-hold and tap behaviors.
struct MicrophoneButton: View {
    let state: ConversationState
    let onTapDown: () -> Void
    let onTapUp: () -> Void
    let onCancel: () -> Void

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0

    private var buttonColor: Color {
        switch state {
        case .idle: return .blue
        case .listening: return .green
        case .thinking: return .orange
        case .speaking: return .purple
        }
    }

    private var iconName: String {
        switch state {
        case .idle: return "mic.fill"
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "stop.fill"
        }
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            ZStack {
                // Pulse ring (visible while listening)
                if state == .listening {
                    Circle()
                        .stroke(buttonColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                }

                // Button background
                Circle()
                    .fill(buttonColor.gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: buttonColor.opacity(0.4), radius: 8, y: 4)

                // Icon
                Image(systemName: iconName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: state == .thinking)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: state)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onChange(of: state) { _, newState in
            if newState == .listening {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .onChanged { _ in
                    if state == .idle {
                        isPressed = true
                        onTapDown()
                    }
                }
        )
    }

    // MARK: - Actions

    private func handleTap() {
        switch state {
        case .idle:
            onTapDown()
        case .listening:
            onTapUp()
        case .thinking, .speaking:
            onCancel()
        }
    }

    // MARK: - Animation

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            pulseScale = 1.0
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Start speaking"
        case .listening: return "Stop listening"
        case .thinking: return "Cancel thinking"
        case .speaking: return "Stop speaking"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .idle: return "Tap to start voice conversation"
        case .listening: return "Tap to send your message"
        case .thinking: return "Tap to cancel"
        case .speaking: return "Tap to interrupt"
        }
    }
}

#Preview("Microphone Button - Idle") {
    MicrophoneButton(state: .idle, onTapDown: {}, onTapUp: {}, onCancel: {})
        .padding()
        .background(Color.black)
}

#Preview("Microphone Button - Listening") {
    MicrophoneButton(state: .listening, onTapDown: {}, onTapUp: {}, onCancel: {})
        .padding()
        .background(Color.black)
}

#Preview("Microphone Button - Thinking") {
    MicrophoneButton(state: .thinking, onTapDown: {}, onTapUp: {}, onCancel: {})
        .padding()
        .background(Color.black)
}

#Preview("Microphone Button - Speaking") {
    MicrophoneButton(state: .speaking, onTapDown: {}, onTapUp: {}, onCancel: {})
        .padding()
        .background(Color.black)
}
