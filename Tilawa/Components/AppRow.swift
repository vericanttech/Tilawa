import SwiftUI

/// Row with a custom leading label (e.g. `Label(token)` from FamilyControls in the caller).
struct AppRow<Leading: View>: View {
    let leading: Leading
    let isOn: Bool
    let onToggle: (Bool) -> Void

    init(
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.leading = leading()
        self.isOn = isOn
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingM) {
            leading

            Spacer()

            Toggle("", isOn: Binding(get: { isOn }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(DesignTokens.gold)
        }
        .padding(DesignTokens.spacingM)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusLg).stroke(DesignTokens.cardBorder, lineWidth: 1))
    }
}
