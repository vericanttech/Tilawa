import SwiftUI

struct StatCard: View {
    let number: String
    let label: String
    let highlight: Bool

    init(number: String, label: String, highlight: Bool = false) {
        self.number = number
        self.label = label
        self.highlight = highlight
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 28))
                .foregroundColor(highlight ? DesignTokens.goldLight : DesignTokens.primaryText)
            Text(label)
                .font(Font.custom("CormorantGaramond-Regular", size: 11))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                .stroke(DesignTokens.cardBorder, lineWidth: 1)
        )
    }
}
