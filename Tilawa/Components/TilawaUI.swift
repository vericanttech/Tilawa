import SwiftUI

// MARK: - Buttons

/// Full-width filled teal button (56pt), used for every primary action.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(enabled ? .white : DesignTokens.accent)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous)
                    .fill(enabled
                          ? (configuration.isPressed ? DesignTokens.accentPressed : DesignTokens.accent)
                          : DesignTokens.accentTint)
            )
    }
}

/// Soft teal button for secondary actions that still deserve weight.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DesignTokens.accent)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous)
                    .fill(DesignTokens.accentTint.opacity(configuration.isPressed ? 0.7 : 1))
            )
    }
}

/// Plain text button in the accent color (e.g. "Not now", "Browse all").
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DesignTokens.accent.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(minHeight: 44)
    }
}

/// Round 44pt icon button (back, close).
struct CircleIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var background: Color = DesignTokens.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Surfaces

extension View {
    /// White rounded card.
    func card(padding: CGFloat = DesignTokens.spacingXl, radius: CGFloat = DesignTokens.radiusCard) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DesignTokens.surface)
            )
    }
}

/// Small uppercase label in accent color ("NOW READING").
struct Overline: View {
    let text: String
    var color: Color = DesignTokens.accent

    var body: some View {
        Text(text.uppercased())
            .font(DesignTokens.overline)
            .tracking(1)
            .foregroundColor(color)
    }
}

/// Pill with a flame icon: "12 days".
struct StreakPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.streak)
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(DesignTokens.surface))
        .accessibilityElement(children: .combine)
    }
}

/// Plain white pill.
struct InfoPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(DesignTokens.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(DesignTokens.surface))
    }
}

/// Thin rounded progress bar.
struct LineProgress: View {
    let value: Double // 0...1
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.track)
                Capsule().fill(DesignTokens.accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

/// Circular progress ring with a percentage label.
struct RingProgress: View {
    let value: Double
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle().stroke(DesignTokens.track, lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(DesignTokens.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignTokens.ink)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(Int((value * 100).rounded())) percent")
    }
}

/// Step indicator used in onboarding ("Step 2 of 3" bars).
struct StepBars: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < current ? DesignTokens.accent : DesignTokens.outline)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// Segmented control drawn in the Tilawa style (white thumb on soft track).
struct TilawaSegmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let label = options[index].1
                let on = value == selection
                Button {
                    selection = value
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: on ? .bold : .semibold))
                        .foregroundColor(on ? DesignTokens.ink : DesignTokens.mutedStrong)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSm, style: .continuous)
                                .fill(on ? DesignTokens.surface : Color.clear)
                                .shadow(color: on ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusMd, style: .continuous).fill(DesignTokens.track))
    }
}

/// Small numbered verse badge.
struct VerseBadge: View {
    let number: Int
    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DesignTokens.accent)
                .frame(minWidth: 28, minHeight: 28)
                .background(Circle().fill(DesignTokens.accentTint))
            Rectangle().fill(DesignTokens.hairline).frame(height: 1)
        }
        .accessibilityLabel("Ayah \(number)")
    }
}
