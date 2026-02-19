import SwiftUI

/// A dismissable error banner shown at the top of the screen.
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

#Preview("Error Banner") {
    VStack(spacing: 16) {
        ErrorBanner(message: "Azure Speech is not configured.") {}
        ErrorBanner(message: "Network error: The request timed out. Please try again later.") {}
    }
    .padding(.vertical)
    .background(Color.black)
}
