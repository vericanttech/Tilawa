import SwiftUI

/// The daily moment: shown when the person opens Tilawa from a paused app (or taps "Read now").
/// Reading (Get familiar / Read with meaning) or recall (Muraja'ah), then the "Done" screen.
struct GateView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var done: DoneInfo?
    /// The wird this pause reads, fixed when it opens (outer nil = not decided yet).
    @State private var wirdId: Int??

    var body: some View {
        let wird = wirdId ?? appState.resolveGateWird()
        Group {
            if let done {
                DoneView(info: done, streakDays: appState.state.streakDays, unlockText: unlockText) {
                    shield.showingCompletion = false
                    self.done = nil
                }
            } else if appState.state.goal == .review && wird == nil {
                RecallView(appState: appState, onClose: close, onFinish: finish)
            } else {
                // A wird is read, even when the goal is Muraja'ah.
                ReadingView(appState: appState, wirdId: wird, onClose: close, onFinish: finish)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: done != nil)
        .onAppear { if wirdId == nil { wirdId = .some(appState.resolveGateWird()) } }
    }

    private var unlockText: String {
        guard Features.appPausing else { return "Well done. Your next reminder picks up from here." }
        switch shield.nextSessionDelay {
        case .m15: return "Your apps are open for the next 15 minutes."
        case .m30: return "Your apps are open for the next 30 minutes."
        case .m60: return "Your apps are open for the next hour."
        case .h2: return "Your apps are open for the next 2 hours."
        case .none: return "Your apps are open."
        }
    }

    private func close() {
        appState.gateWird = .auto
        shield.userRequestedReadingGate = false
    }

    private func finish(_ info: DoneInfo) {
        appState.gateWird = .auto
        shield.showingCompletion = true
        shield.userRequestedReadingGate = false
        if Features.appPausing { shield.completeGateAndScheduleNextLock() }
        // Just read: the next reminder comes a full interval from now, and the one showing is cleared.
        Reminders.clearDelivered()
        appState.rescheduleReminders()
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

// MARK: - Reading (Get familiar / Read with meaning / a wird)

/// A reading pause, one page at a time. After the first page, "Keep reading" turns to the next one
/// (the rest of a wird, the next wird due today, then the main surah), and every page read counts.
struct ReadingView: View {
    @ObservedObject var appState: AppStateStore
    let wirdId: Int?
    let onClose: () -> Void
    let onFinish: (DoneInfo) -> Void

    @State private var page: ReadingSegment?
    /// Pages already counted in this pause, and surahs finished along the way.
    @State private var read: [ReadingSegment] = []
    @State private var finished: [String] = []
    @State private var next: ReadingSegment?
    @State private var duration: Int = 18
    @State private var elapsed: Int = 0
    @State private var timer: Timer?
    @State private var showingTextSettings = false

    private var verses: [Verse] { page?.verses ?? [] }
    private var surah: Surah? { page?.surah }
    private var isReady: Bool { elapsed >= duration }
    private var sessionCount: Int { read.reduce(0) { $0 + $1.verses.count } }

    var body: some View {
        VStack(spacing: 0) {
            GateHeader(title: "Surah \(surah?.name ?? "")", onClose: onClose) { textMenu }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("top")
                        if page?.wirdId != nil && verses.first?.id == 1 {
                            Text("TODAY’S WIRD")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(DesignTokens.muted)
                                .padding(.bottom, 16)
                        }
                        if appState.state.readIn == .english, verses.contains(where: { $0.translation == nil }) {
                            Text("English meaning isn’t available for this surah yet.")
                                .font(DesignTokens.caption)
                                .foregroundColor(DesignTokens.muted)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 16)
                        }
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                            if index > 0 { VerseDivider() }
                            verseBlock(verse)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .onChange(of: page?.key) { _ in proxy.scrollTo("top", anchor: .top) }
            }

            GateBottomBar(label: barLabel, detail: isReady ? rangeText : "\(rangeText) · \(timeLeft)") {
                ThinProgress(value: duration > 0 ? Double(elapsed) / Double(duration) : 1)
                bottomButtons
            }
        }
        .background(DesignTokens.paper.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { ZStack(alignment: .topTrailing) { textSettingsOverlay } }
        .onAppear {
            if page == nil { show(appState.firstSegment(wirdId: wirdId)) }
        }
        .onChange(of: isReady) { ready in
            if ready, let page { next = appState.nextSegment(after: page) }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private var barLabel: String {
        if sessionCount > 0 { return sessionCount == 1 ? "1 verse read" : "\(sessionCount) verses read" }
        return page?.wirdId != nil ? "Today’s wird" : "Reading moment"
    }

    @ViewBuilder
    private var bottomButtons: some View {
        if isReady, let next, let surah, let page {
            HStack(spacing: 10) {
                Button(next.surah.id != surah.id ? "Next: \(next.surah.name)" : "Keep reading") {
                    recordCurrent()
                    show(appState.nextSegment(after: page))
                }
                .buttonStyle(SoftButtonStyle())
                Button("Done") { recordCurrent(); end() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else if isReady {
            Button(read.isEmpty ? "Done reading" : "Done") { recordCurrent(); end() }
                .buttonStyle(PrimaryButtonStyle())
        } else if !read.isEmpty {
            // Mid-page after reading more: stop here, counting only the pages finished.
            HStack(spacing: 10) {
                WaitLabel(text: "Reading…")
                    .accessibilityLabel("Keep reading. \(duration - elapsed) seconds left")
                Button("Stop here", action: end)
                    .buttonStyle(SoftButtonStyle())
            }
        } else {
            WaitLabel(text: "Reading…")
                .accessibilityLabel("Keep reading. \(duration - elapsed) seconds left")
        }
    }

    private var textMenu: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { showingTextSettings.toggle() }
        } label: {
            Text("Aa")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Text settings")
    }

    /// Text settings in the reading style (the system menu looked out of place on the paper).
    @ViewBuilder
    private var textSettingsOverlay: some View {
        if showingTextSettings {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showingTextSettings = false } }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                MenuLabel(text: "Read in")
                ReadInPicker(selection: Binding(get: { appState.state.readIn }, set: { appState.state.readIn = $0 }))
                    .padding(.top, 8)
                MenuLabel(text: "Also show")
                    .padding(.top, 16)
                ForEach(Array(ReadIn.allCases.filter { $0 != appState.state.readIn }.enumerated()), id: \.element) { index, other in
                    if index > 0 { Rectangle().fill(DesignTokens.paperLine).frame(height: 1) }
                    switch other {
                    case .arabic:
                        TextSettingRow(title: "Arabic", detail: "The verse in Arabic script",
                                       isOn: Binding(get: { appState.state.showArabic }, set: { appState.state.showArabic = $0 }))
                    case .transliteration:
                        TextSettingRow(title: "Transliteration", detail: "How it sounds, in Latin letters",
                                       isOn: Binding(get: { appState.state.showTransliteration }, set: { appState.state.showTransliteration = $0 }))
                    case .english:
                        TextSettingRow(title: "Meaning", detail: "The English translation",
                                       isOn: Binding(get: { appState.state.showMeaning }, set: { appState.state.showMeaning = $0 }))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignTokens.surface)
                    .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DesignTokens.paperLine, lineWidth: 1))
            .padding(.top, 52)
            .padding(.trailing, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
    }

    private func verseBlock(_ verse: Verse) -> some View {
        VStack(spacing: 14) {
            VerseMark(number: verse.id)
            VerseLines(verse: verse, state: appState.state)
        }
        .frame(maxWidth: .infinity)
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

    /// Shows `segment` and starts its reading timer.
    private func show(_ segment: ReadingSegment?) {
        page = segment
        next = nil
        guard let segment else {
            duration = 0
            elapsed = 0
            return
        }
        let base = segment.verses.reduce(0) { $0 + $1.durationSeconds }
        let scale = appState.state.readingSpeed.secondsPerWordMultiplier / ReadingSpeed.normal.secondsPerWordMultiplier
        // Reading the meaning as well takes longer.
        let meaningExtra = appState.state.goal == .meaning ? 1.6 : 1.0
        duration = max(5, Int((Double(base) * scale * meaningExtra).rounded()))
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

    private func recordCurrent() {
        guard let page else { return }
        if let name = appState.recordSegment(page) { finished.append(name) }
        read.append(page)
    }

    private func end() {
        timer?.invalidate()
        if let info = appState.doneInfo(read: read, finished: finished) {
            onFinish(info)
        } else {
            onClose()
        }
    }
}

// MARK: - Reading surface pieces

/// Quiet header on the paper: a small letterspaced title, with close and text settings kept faint.
struct GateHeader<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(DesignTokens.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(DesignTokens.accent)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            trailing()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

/// The one place to act, set apart from the reading surface by a hairline.
struct GateBottomBar<Content: View>: View {
    let label: String
    let detail: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(DesignTokens.muted)
                Spacer()
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
                    .monospacedDigit()
            }
            content()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(DesignTokens.paper.overlay(Rectangle().fill(DesignTokens.paperLine).frame(height: 1), alignment: .top))
    }
}

struct ThinProgress: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(DesignTokens.paperLine)
                Rectangle().fill(DesignTokens.accent)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
                    .animation(.linear(duration: 1), value: value)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

/// Calm stand-in for the button while the minimum reading time runs.
struct WaitLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DesignTokens.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.accentTint))
    }
}

/// One verse: the text the person reads, large; the others smaller underneath.
struct VerseLines: View {
    let verse: Verse
    let state: AppState

    /// Without a translation, an English reader still gets the Arabic.
    private var main: ReadIn {
        state.readIn == .english && verse.translation == nil ? .arabic : state.readIn
    }

    var body: some View {
        VStack(spacing: 14) {
            switch main {
            case .arabic:
                ReadingArabic(text: verse.text, size: 44, color: DesignTokens.ink)
            case .transliteration:
                Text(verse.transliteration)
                    .font(DesignTokens.serif(28))
                    .foregroundColor(DesignTokens.ink)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            case .english:
                TranslationText.make(verse.translation ?? "")
                    .font(DesignTokens.serif(23))
                    .foregroundColor(DesignTokens.ink)
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if main != .arabic, state.showArabic {
                ReadingArabic(text: verse.text, size: main == .transliteration ? 28 : 30, color: DesignTokens.mutedStrong)
            }
            if main != .transliteration, state.showTransliteration {
                ReadingTransliteration(text: verse.transliteration, size: main == .arabic ? 20 : 17)
            }
            if main != .english, state.showMeaning, let translation = verse.translation {
                TranslationText.make(translation)
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.inkSoft)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if verse.translation != nil, main == .english || state.showMeaning {
                FootnotesView(text: verse.footnotes)
            }
        }
    }
}

struct MenuLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(DesignTokens.muted)
            .padding(.top, 6)
    }
}

/// Three-way "Read in" picker, styled like the rest of the app rather than the system segmented control.
struct ReadInPicker: View {
    @Binding var selection: ReadIn
    var long = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReadIn.allCases) { option in
                let on = option == selection
                Button { selection = option } label: {
                    Text(long ? option.label : option.shortLabel)
                        .font(.system(size: 14, weight: on ? .semibold : .regular))
                        .foregroundColor(on ? DesignTokens.ink : DesignTokens.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusSm, style: .continuous)
                            .fill(on ? DesignTokens.surface : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusMd, style: .continuous).fill(DesignTokens.track))
    }
}

/// One row of the text settings card: title, a short explanation, and a teal switch.
struct TextSettingRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? DesignTokens.ink : DesignTokens.muted)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
            }
        }
        .tint(DesignTokens.accent)
        .padding(.vertical, 12)
    }
}

/// Small outlined verse number, centered above the verse.
struct VerseMark: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.accent)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(DesignTokens.accent.opacity(0.45), lineWidth: 1))
            .accessibilityLabel("Ayah \(number)")
    }
}

struct VerseDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.paperLine)
            .frame(width: 56, height: 1)
            .padding(.vertical, 22)
            .accessibilityHidden(true)
    }
}

/// Large centered Arabic for the reading surface.
struct ReadingArabic: View {
    let text: String
    let size: CGFloat
    let color: Color
    var body: some View {
        Text(text)
            .font(DesignTokens.readingArabic(size))
            .foregroundColor(color)
            .lineSpacing(size * 0.35)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReadingTransliteration: View {
    let text: String
    let size: CGFloat
    var body: some View {
        Text(text)
            .font(DesignTokens.serifItalic(size))
            .foregroundColor(DesignTokens.muted)
            .lineSpacing(size * 0.2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
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
            GateHeader(title: "Muraja’ah · \(surah?.name ?? "")", onClose: onClose) {
                Color.clear.frame(width: 44, height: 44)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let verse {
                        VerseMark(number: verse.id)
                    }
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let verse {
                        // People who don't read the Arabic script recall the transliteration instead.
                        let arabic = appState.state.readIn == .arabic
                        FadingVerse(words: arabic ? verse.words : verse.transliterationWords,
                                    stage: stage, revealed: revealed, arabic: arabic)

                        if stage == 0, arabic, appState.state.showTransliteration {
                            ReadingTransliteration(text: verse.transliteration, size: 20)
                        }
                        if stage == 0, !arabic, appState.state.showArabic {
                            ReadingArabic(text: verse.text, size: 28, color: DesignTokens.mutedStrong)
                        }

                        VerseDivider()
                        meaning(verse)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            GateBottomBar(label: "Review", detail: verse.map { "Ayah \($0.id) of \(surah?.totalVerses ?? 0)" } ?? "") {
                actions
                Text("Your app opens either way")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.muted)
            }
        }
        .background(DesignTokens.paper.ignoresSafeArea())
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate(); timer = nil }
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
    private func meaning(_ verse: Verse) -> some View {
        VStack(spacing: 14) {
            Overline(text: stage == 3 && !revealed ? "Recall the verse that means" : "Meaning", color: DesignTokens.muted)
            if let translation = verse.translation {
                TranslationText.make(translation)
                    .font(DesignTokens.serif(20))
                    .foregroundColor(DesignTokens.inkSoft)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                FootnotesView(text: revealed || stage < 3 ? verse.footnotes : nil)
            } else {
                Text("Ayah \(verse.id) of \(surah?.name ?? "")")
                    .font(DesignTokens.serif(20))
                    .foregroundColor(DesignTokens.inkSoft)
            }
        }
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
            WaitLabel(text: "Take your time · \(max(0, minimum - elapsed))s")
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

/// The verse word by word (Arabic right to left, or transliteration left to right), with words faded or hidden by stage.
struct FadingVerse: View {
    let words: [String]
    let stage: Int
    let revealed: Bool
    var arabic: Bool = true

    var body: some View {
        RightToLeftFlow(spacing: arabic ? 12 : 8, lineSpacing: 6, rightToLeft: arabic) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let look = wordStyle(index)
                Text(word)
                    .font(arabic ? DesignTokens.readingArabic(42) : DesignTokens.serif(28))
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

/// Wrapping layout with centered lines; right to left for Arabic, left to right for transliteration.
struct RightToLeftFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4
    var rightToLeft = true

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

    /// Lines are centered, so a verse sits in the middle of the page like the reading view.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Group words into lines first, then place each line centered, right to left.
        var lines: [[(index: Int, size: CGSize)]] = [[]]
        var lineWidth: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if lineWidth > 0 && lineWidth + spacing + size.width > bounds.width {
                lines.append([])
                lineWidth = 0
            }
            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lines[lines.count - 1].append((index, size))
        }
        var y = bounds.minY
        for line in lines where !line.isEmpty {
            let width = line.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(line.count - 1)
            let height = line.map(\.size.height).max() ?? 0
            if rightToLeft {
                var x = bounds.midX + width / 2
                for item in line {
                    subviews[item.index].place(at: CGPoint(x: x - item.size.width, y: y), proposal: ProposedViewSize(item.size))
                    x -= item.size.width + spacing
                }
            } else {
                var x = bounds.midX - width / 2
                for item in line {
                    subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                    x += item.size.width + spacing
                }
            }
            y += height + lineSpacing
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
            if Features.appPausing {
                Text("Swipe back to your app whenever you’re ready")
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.muted)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 16)
            }
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
