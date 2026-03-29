import SwiftUI

struct UnlockButton: View {
    var readingText: String = "Reading..."
    var readyText: String = "Done · unlock apps"
    let isReady: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            Text(isReady ? readyText : readingText)
                .font(Font.custom("CormorantGaramond-Medium", size: 16))
                .foregroundColor(isReady ? DesignTokens.ink : Color.white.opacity(0.15))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSm)
                        .fill(isReady ? DesignTokens.gold : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSm)
                                .stroke(isReady ? DesignTokens.goldLight : Color.white.opacity(0.07), lineWidth: 1)
                        )
                        .shadow(color: isReady ? DesignTokens.gold.opacity(pulse ? 0.55 : 0.35) : .clear, radius: 12)
                )
        }
        .disabled(!isReady)
        .onAppear {
            guard isReady else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
