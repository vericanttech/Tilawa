import SwiftUI

struct TimerBar: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 2)

                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.gold, DesignTokens.goldPale],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 2)
            }
        }
        .frame(height: 2)
    }
}
