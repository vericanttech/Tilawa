import SwiftUI

/// The daily moment: shown when the person opens Tilawa from a paused app (or taps "Read now").
/// Reading (Get familiar / Read with meaning) or recall (Muraja'ah), then the "Done" screen.
struct GateView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var done: DoneInfo?

    var body: some View {
        Group {
            if let done {
                DoneView(info: done, streakDays: appState.state.streakDays, unlockText: unlockText) {
                    shield.showingCompletion = false
                    self.done = nil
                }
            } else if appState.state.goal == .review {
                RecallView(appState: appState, onClose: close, onFinish: finish)
            } else {
                ReadingView(appState: appState, onClose: close, onFinish: finish)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: done != nil)
    }

    private var unlockText: String {
        switch shield.nextSessionDelay {
        case .m15: return "Your apps are open for the next 15 minutes."
        case .m30: return "Your apps are open for the next 30 minutes."
        case .m60: return "Your apps are open for the next hour."
        case .h2: return "Your apps are open for the next 2 hours."
        case .none: return "Your apps are open."
        }
    }

    private func close() {
        shield.userRequestedReadingGate = false
    }

    private func finish(_ info: DoneInfo) {
        shield.showingCompletion = true
        shield.userRequestedReadingGate = false
        shield.completeGateAndScheduleNextLock()
        done = info
    }
}

// MARK: - Done screen content

struct DoneInfo: Equatable {
    var headline: String
    var chip: String
    var cardLabel: String
    var cardText: String
    var cardTextIsArabic: Bool = false
    var cardRef: String
}

// MARK: - Reading (Get familiar / Read with meaning)

struct ReadingView: View {
    @ObservedObject var appState: AppStateStore
    let onClose: () -> Void
    let onFinish: (DoneInfo) -> Void

    @State private var verses: [Verse] = []
    @State private var duration: Int = 18
    @State private var elapsed: Int = 0
    @State private var timer: Timer?

    private let quran = QuranService.shared
    private var surah: Surah? { quran.surah(id: appState.state.selectedSurahId) }
    private var meaningFirst: Bool { appState.state.meaningFirst || appState.state.goal == .meaning }
    private var isReady: Bool { elapsed >= duration }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    if appState.state.goal == .meaning, verses.contains(where: { $0.translation == nil }) {
                        Text("English meaning isn’t available for this surah yet.")
                            .font(DesignTokens.caption)
                            .foregroundColor(DesignTokens.muted)
                    }
                    ForEach(verses) { verse in
                        verseBlock(verse)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            VStack(spacing: 14) {
                LineProgress(value: duration > 0 ? Double(elapsed) / Double(duration) : 1)
                if isReady {
                    Button("Done reading", action: finish)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Take your time · \(timeLeft)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.accentTint))
                        .accessibilityLabel("Keep reading. \(duration - elapsed) seconds left")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(DesignTokens.surface.overlay(Rectangle().fill(DesignTokens.hairline).frame(height: 1), alignment: .top))
        }
        .background(DesignTokens.surface.ignoresSafeArea())
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close", background: DesignTokens.surfaceMuted, action: onClose)
            Spacer()
            VStack(spacing: 2) {
                Text(surah?.name ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                Text(rangeText)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
            }
            Spacer()
            Menu {
                Toggle("Meaning first", isOn: Binding(
                    get: { appState.state.meaningFirst },
                    set: { appState.state.meaningFirst = $0 }
                ))
                Toggle("Show transliteration", isOn: Binding(
                    get: { appState.state.showTransliteration },
                    set: { appState.state.showTransliteration = $0 }
                ))
            } label: {
                Text("Aa")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DesignTokens.surfaceMuted))
            }
            .accessibilityLabel("Text settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func verseBlock(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VerseBadge(number: verse.id)
            if meaningFirst, let translation = verse.translation {
                TranslationText.make(translation)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                arabic(verse, size: 22, color: DesignTokens.mutedStrong)
                transliteration(verse, size: 13)
                FootnotesView(text: verse.footnotes)
            } else {
                arabic(verse, size: 30, color: DesignTokens.ink)
                transliteration(verse, size: 14)
                if let translation = verse.translation {
                    TranslationText.make(translation)
                        .font(DesignTokens.body)
                        .foregroundColor(DesignTokens.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    FootnotesView(text: verse.footnotes)
                }
            }
        }
    }

    private func arabic(_ verse: Verse, size: CGFloat, color: Color) -> some View {
        Text(verse.text)
            .font(DesignTokens.arabic(size))
            .foregroundColor(color)
            .lineSpacing(size * 0.5)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func transliteration(_ verse: Verse, size: CGFloat) -> some View {
        if appState.state.showTransliteration {
            Text(verse.transliteration)
                .font(.system(size: size).italic())
                .foregroundColor(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangeText: String {
        guard let surah, let first = verses.first?.id, let last = verses.last?.id else { return "" }
        return first == last
            ? "Ayah \(first) of \(surah.totalVerses)"
            : "Ayahs \(first)–\(last) of \(surah.totalVerses)"
    }

    private var timeLeft: String {
        let s = max(0, duration - elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func start() {
        guard let surah,
              let chunk = quran.currentChunk(surahId: surah.id, chunkIndex: appState.state.currentChunkIndex) else {
            verses = []
            duration = 0
            return
        }
        verses = chunk.verses
        let scale = appState.state.readingSpeed.secondsPerWordMultiplier / ReadingSpeed.normal.secondsPerWordMultiplier
        // Reading the meaning as well takes longer.
        let meaningExtra = appState.state.goal == .meaning ? 1.6 : 1.0
        duration = max(5, Int((Double(chunk.duration) * scale * meaningExtra).rounded()))
        elapsed = 0
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if elapsed < duration { elapsed += 1 }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func finish() {
        timer?.invalidate()
        guard let surah else { return }
        let count = verses.count
        let pass = appState.state.timesThroughSurah + 1
        let finishedPass = appState.recordRead(ayahCount: count, surah: surah)
        let readUpTo = verses.last?.id ?? 0

        let chip: String
        if finishedPass {
            chip = "Finished \(surah.name) · \(pass)×"
        } else if appState.state.goal == .familiar {
            chip = "\(surah.name) · \(Ordinal.string(pass)) time through"
        } else {
            chip = "\(surah.name) \(readUpTo)/\(surah.totalVerses)"
        }

        let keep = verses.last(where: { $0.translation != nil }) ?? verses.last
        onFinish(DoneInfo(
            headline: count == 1 ? "1 verse read" : "\(count) verses read",
            chip: chip,
            cardLabel: "Take with you",
            cardText: keep?.translation.map { "“\($0)”" } ?? keep?.text ?? "",
            cardTextIsArabic: keep?.translation == nil,
            cardRef: keep.map { "\(surah.name) \(surah.id):\($0.id)" } ?? ""
        ))
    }
}

// MARK: - Recall (Muraja'ah)

struct RecallView: View {
    @ObservedObject var appState: AppStateStore
    let onClose: () -> Void
    let onFinish: (DoneInfo) -> Void

    @State private var verse: Verse?
    @State private var stage = 0
    @State private var revealed = false
    @State private var elapsed = 0
    @State private var minimum = 5
    @State private var timer: Timer?

    private let quran = QuranService.shared
    private var surah: Surah? { quran.surah(id: appState.state.selectedSurahId) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let verse {
                        FadingVerse(words: verse.words, stage: stage, revealed: revealed)

                        if stage == 0, appState.state.showTransliteration {
                            Text(verse.transliteration)
                                .font(.system(size: 14).italic())
                                .foregroundColor(DesignTokens.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        promptBox(verse)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                actions
                Text("Your app opens either way")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(DesignTokens.surface.overlay(Rectangle().fill(DesignTokens.hairline).frame(height: 1), alignment: .top))
        }
        .background(DesignTokens.surface.ignoresSafeArea())
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close", background: DesignTokens.surfaceMuted, action: onClose)
            Spacer()
            VStack(spacing: 2) {
                Text("Muraja’ah · \(surah?.name ?? "")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                Text(verse.map { "Ayah \($0.id) · review" } ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var caption: String {
        if revealed { return stage == 3 ? "Words you recalled are shown in green." : "Here’s the full verse." }
        switch stage {
        case 0: return "Read the whole verse, so it becomes familiar."
        case 1: return "Some words have faded. Fill them in as you read."
        case 2: return "Just the first word. Recite the rest in your head."
        default: return "Recall the whole verse, then check yourself."
        }
    }

    @ViewBuilder
    private func promptBox(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Overline(text: stage == 3 && !revealed ? "Recall the verse that means" : "Meaning")
            if let translation = verse.translation {
                TranslationText.make(translation)
                    .font(DesignTokens.body)
                    .foregroundColor(DesignTokens.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                FootnotesView(text: revealed || stage < 3 ? verse.footnotes : nil)
            } else {
                Text("Ayah \(verse.id) of \(surah?.name ?? "")")
                    .font(DesignTokens.body)
                    .foregroundColor(DesignTokens.inkSoft)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.mist))
    }

    @ViewBuilder
    private var actions: some View {
        if stage == 3 && !revealed {
            Button("Tap to check") { withAnimation { revealed = true } }
                .buttonStyle(PrimaryButtonStyle())
        } else if stage == 3 && revealed {
            HStack(spacing: 10) {
                Button("Review again soon") { finish(recalled: false) }
                    .buttonStyle(SoftButtonStyle())
                Button("I knew it") { finish(recalled: true) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else if elapsed < minimum {
            Text("Take your time · \(max(0, minimum - elapsed))s")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignTokens.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.accentTint))
        } else {
            VStack(spacing: 4) {
                Button("Done") { finish(recalled: !revealed) }
                    .buttonStyle(PrimaryButtonStyle())
                if stage > 0 && !revealed {
                    Button("Show the full verse") { withAnimation { revealed = true } }
                        .buttonStyle(TextButtonStyle())
                }
            }
        }
    }

    private func start() {
        guard let surah, let next = StatsService.shared.nextReviewVerse(in: surah, state: appState.state) else { return }
        verse = next
        stage = StatsService.shared.reviewStage(for: next.id, state: appState.state)
        revealed = false
        elapsed = 0
        let scale = appState.state.readingSpeed.secondsPerWordMultiplier / ReadingSpeed.normal.secondsPerWordMultiplier
        minimum = stage == 3 ? 0 : max(5, Int((Double(next.durationSeconds) * scale).rounded()))
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if elapsed < minimum { elapsed += 1 }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func finish(recalled: Bool) {
        timer?.invalidate()
        guard let surah, let verse else { return }
        appState.recordReview(verseId: verse.id, recalled: recalled)
        let strong = StatsService.shared.strongVerseCount(in: surah, state: appState.state)
        let upcoming = appState.state.reviewItems
            .filter { $0.value.dueAt > Date() }
            .sorted { $0.value.dueAt < $1.value.dueAt }
            .prefix(2)
            .map { "Ayah \($0.key) · \(RelativeDue.string(for: $0.value.dueAt))" }
            .joined(separator: "\n")
        onFinish(DoneInfo(
            headline: recalled ? "Ayah \(verse.id) reviewed" : "We’ll bring ayah \(verse.id) back soon",
            chip: "\(strong) of \(surah.totalVerses) strong",
            cardLabel: "Coming up next",
            cardText: upcoming.isEmpty ? "Ayah \(verse.id) · soon" : upcoming,
            cardRef: "Spaced out so every verse stays fresh"
        ))
    }
}

/// Arabic verse laid out word by word (right to left), with words faded or hidden by stage.
struct FadingVerse: View {
    let words: [String]
    let stage: Int
    let revealed: Bool

    var body: some View {
        RightToLeftFlow(spacing: 12, lineSpacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let look = wordStyle(index)
                Text(word)
                    .font(DesignTokens.arabic(32))
                    .foregroundColor(look.color)
                    .padding(.bottom, 2)
                    .overlay(
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [2, 4]))
                            .foregroundColor(look.line)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .animation(.easeInOut(duration: 0.3), value: revealed)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func wordStyle(_ index: Int) -> (color: Color, line: Color) {
        var hidden = false
        var faded = false
        switch stage {
        case 1: faded = index % 2 == 1
        case 2: hidden = index > 0
        case 3: hidden = true
        default: break
        }
        if revealed && (hidden || faded) { return (DesignTokens.accent, .clear) }
        if hidden { return (.clear, DesignTokens.outline) }
        if faded { return (DesignTokens.outline, .clear) }
        return (DesignTokens.ink, .clear)
    }

    private var accessibilityText: String {
        if revealed || stage == 0 { return words.joined(separator: " ") }
        if stage == 2, let first = words.first { return "\(first), then recall the rest" }
        return "Recall this verse"
    }
}

/// Wrapping layout that places items from right to left, as Arabic text flows.
struct RightToLeftFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if lineWidth > 0 && lineWidth + spacing + size.width > maxWidth {
                totalHeight += lineHeight + lineSpacing
                widest = max(widest, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        widest = max(widest, lineWidth)
        return CGSize(width: proposal.width ?? widest, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.maxX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x < bounds.maxX && x - spacing - size.width < bounds.minX {
                x = bounds.maxX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            if x < bounds.maxX { x -= spacing }
            view.place(at: CGPoint(x: x - size.width, y: y), proposal: ProposedViewSize(size))
            x -= size.width
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Done

struct DoneView: View {
    let info: DoneInfo
    let streakDays: Int
    let unlockText: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DesignTokens.accent)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(DesignTokens.accentTint))
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text(info.headline)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignTokens.ink)
                        .multilineTextAlignment(.center)
                    Text(unlockText)
                        .font(DesignTokens.body)
                        .foregroundColor(DesignTokens.muted)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    StreakPill(text: streakDays == 1 ? "1-day streak" : "\(streakDays)-day streak")
                    InfoPill(text: info.chip)
                }
            }
            .padding(.horizontal, 24)
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Overline(text: info.cardLabel)
                if info.cardTextIsArabic {
                    Text(info.cardText)
                        .font(DesignTokens.arabic(22))
                        .foregroundColor(DesignTokens.inkSoft)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                } else {
                    TranslationText.make(info.cardText)
                        .font(DesignTokens.body)
                        .foregroundColor(DesignTokens.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(info.cardRef)
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.muted)
            }
            .card(padding: 20, radius: DesignTokens.radiusXl)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
            Text("Swipe back to your app whenever you’re ready")
                .font(DesignTokens.caption)
                .foregroundColor(DesignTokens.muted)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .background(DesignTokens.mist.ignoresSafeArea())
    }
}

// MARK: - Helpers

enum Ordinal {
    static func string(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

enum RelativeDue {
    static func string(for date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 60 { return "in \(max(1, minutes)) min" }
        if cal.isDateInToday(date) { return "later today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 2
        return "in \(days) days"
    }
}
