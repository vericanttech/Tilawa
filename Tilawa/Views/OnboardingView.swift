import FamilyControls
import ManagedSettings
import SwiftUI
import UserNotifications

/// First launch: Welcome → What brings you here → How you read → Choose apps → Choose a surah.
struct OnboardingView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var step = 0
    @State private var showPicker = false
    @State private var simulatorAlert = false
    @State private var pauseLength: PauseLength = .medium

    private let quran = QuranService.shared

    var body: some View {
        ZStack {
            DesignTokens.mist.ignoresSafeArea()
            switch step {
            case 0: welcome
            case 1: goalStep
            case 2: readInStep
            case 3: if Features.appPausing { appsStep } else { remindersStep }
            default: surahStep
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
        .alert("Screen Time isn’t available in the Simulator", isPresented: $simulatorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Run Tilawa on an iPhone to choose apps. You can continue setup without them.")
        }
    }

    // MARK: - 1 · Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "moon")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.accent)
                Text("Tilawa")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 24)

            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("اقرأ")
                        .font(DesignTokens.arabic(56))
                        .foregroundColor(DesignTokens.accent)
                    Text("READ")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(DesignTokens.onAccentTint)
                }
                .frame(width: 168, height: 204)
                .background(
                    UnevenArch()
                        .fill(DesignTokens.accentTint)
                )
                .accessibilityHidden(true)
                Spacer()
            }

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Turn the moments you’d scroll into time with the Quran.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A gentle reminder every few hours: two or three verses, read in under a minute.")
                    .font(DesignTokens.body)
                    .foregroundColor(DesignTokens.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                reason("Get familiar with a surah you love")
                reason("Keep what you’ve memorized fresh")
                reason("Read the meaning, even without Arabic")
            }
            .padding(.top, 24)
            .padding(.bottom, 28)

            Button("Get started") { step = 1 }
                .buttonStyle(PrimaryButtonStyle())
            Text("Setup takes about a minute")
                .font(DesignTokens.caption)
                .foregroundColor(DesignTokens.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func reason(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(DesignTokens.accent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(DesignTokens.accentTint))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
        }
    }

    // MARK: - 2 · What brings you here

    private var goalStep: some View {
        stepScaffold(
            current: 1,
            back: { step = 0 },
            title: "What brings you to Tilawa?",
            subtitle: "This shapes what you read at each reminder. You can switch anytime.",
            continueAction: { step = 2 }
        ) {
            VStack(spacing: 12) {
                ForEach(ReadingGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: ReadingGoal) -> some View {
        let on = appState.state.goal == goal
        return Button {
            appState.setGoal(goal)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: goal.systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(on ? .white : DesignTokens.accent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(on ? DesignTokens.accent : DesignTokens.accentTint))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(goal.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(DesignTokens.ink)
                        if let arabic = goal.arabicTitle {
                            Text(arabic)
                                .font(DesignTokens.arabic(17))
                                .foregroundColor(DesignTokens.accent)
                        }
                    }
                    Text(goal.summary)
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: DesignTokens.radiusXl, style: .continuous).fill(DesignTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusXl, style: .continuous)
                .stroke(on ? DesignTokens.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: - 3 · How you read

    /// Which text the person can read: it becomes the large text at every pause.
    private var readInStep: some View {
        stepScaffold(
            current: 2,
            back: { step = 1 },
            title: "How do you read the Quran?",
            subtitle: "We’ll show that large at each pause. You can change it anytime with Aa.",
            continueAction: { step = 3 }
        ) {
            VStack(spacing: 12) {
                ForEach(ReadIn.allCases) { option in
                    readInCard(option)
                }
            }
        }
    }

    private func readInCard(_ option: ReadIn) -> some View {
        let on = appState.state.readIn == option
        // A real first verse, so people can tell which one they can read.
        let sample = quran.surah(id: 1)?.verses.first
        let (title, detail): (String, String) = {
            switch option {
            case .arabic: return ("I read Arabic", "The Arabic is shown large.")
            case .transliteration: return ("I sound it out in Latin letters", "For when you can’t read the Arabic script yet.")
            case .english: return ("I read for the meaning", "The English meaning is shown large.")
            }
        }()
        return Button {
            appState.state.readIn = option
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(DesignTokens.ink)
                        Text(detail)
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(on ? DesignTokens.accent : DesignTokens.outline)
                }
                if let sample {
                    Group {
                        switch option {
                        case .arabic:
                            Text(sample.text)
                                .font(DesignTokens.readingArabic(30))
                                .environment(\.layoutDirection, .rightToLeft)
                        case .transliteration:
                            Text(sample.transliteration)
                                .font(DesignTokens.serif(22))
                        case .english:
                            // Only the licensed translation text, never a paraphrase.
                            if let translation = sample.translation {
                                TranslationText.make(translation)
                                    .font(DesignTokens.serif(19))
                            }
                        }
                    }
                    .foregroundColor(DesignTokens.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignTokens.paper))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: DesignTokens.radiusXl, style: .continuous).fill(DesignTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusXl, style: .continuous)
                .stroke(on ? DesignTokens.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: - 4 · Choose apps

    private var appsStep: some View {
        stepScaffold(
            current: 3,
            back: { step = 2 },
            title: "Which apps pull you in?",
            subtitle: "Each time you open one, you’ll spend a few seconds with the Quran first. You can change them anytime.",
            continueAction: {
                if shield.hasAppsToShield {
                    shield.applyShield()
                    shield.startFullDayMonitoring()
                    shield.skipGateAfterAddingApps = true
                }
                step = 4
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    let apps = Array(shield.selection.applicationTokens)
                    let cats = Array(shield.selection.categoryTokens)
                    ForEach(Array(apps.enumerated()), id: \.offset) { _, token in
                        selectedRow { Label(token).labelStyle(.titleAndIcon) }
                    }
                    ForEach(Array(cats.enumerated()), id: \.offset) { _, token in
                        selectedRow { Label(token).labelStyle(.titleAndIcon) }
                    }
                    Button {
                        Task { await openPicker() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                            Text(shield.hasAppsToShield ? "Add or remove apps" : "Choose apps")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(DesignTokens.accent)
                        .frame(minHeight: 56)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusXl, style: .continuous).fill(DesignTokens.surface))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                    Text("Apps are chosen through Apple Screen Time. Tilawa never sees which apps you use or how long you use them.")
                        .font(DesignTokens.caption)
                        .foregroundColor(DesignTokens.onAccentTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.accentTint))
            }
        }
    }

    private func selectedRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 14) {
            content()
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.ink)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DesignTokens.accent)
        }
        .frame(minHeight: 60)
        .overlay(Rectangle().fill(DesignTokens.hairline).frame(height: 1), alignment: .bottom)
    }

    private func openPicker() async {
        if Device.isSimulator {
            simulatorAlert = true
            return
        }
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            await shield.requestAuthorization()
        }
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            showPicker = true
        }
    }

    // MARK: - 4 · Reminders

    private var remindersStep: some View {
        stepScaffold(
            current: 3,
            back: { step = 2 },
            title: "When should we remind you?",
            subtitle: "A gentle notification with your next few verses. Read them right away, or whenever you’re ready.",
            continueTitle: "Turn on reminders",
            continueAction: {
                appState.state.remindersOn = true
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    await MainActor.run { step = 4 }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ReminderPreview(appState: appState)
                ReminderOptions(appState: appState)
                Button("Not now") {
                    appState.state.remindersOn = false
                    step = 4
                }
                .buttonStyle(TextButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 5 · Choose a surah

    private var surahStep: some View {
        stepScaffold(
            current: 4,
            back: { step = 3 },
            title: surahTitle,
            subtitle: surahSubtitle,
            continueTitle: "Start",
            continueAction: { appState.completeOnboarding() }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(SuggestedSurah.starters) { suggestion in
                    if let surah = quran.surah(id: suggestion.id) {
                        surahChoice(surah, note: suggestion.note)
                    }
                }
                NavigationLink {
                    SurahLibraryView(appState: appState, showsTitle: true)
                } label: {
                    Text("Browse all 114 surahs")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                        .frame(minHeight: 44)
                }

                if appState.state.goal != .review {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How long is each reading?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignTokens.ink)
                        TilawaSegmented(
                            options: PauseLength.allCases.map { ($0, $0.label) },
                            selection: Binding(
                                get: { pauseLength },
                                set: {
                                    pauseLength = $0
                                    appState.state.readingSpeed = $0.speed
                                }
                            )
                        )
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var surahTitle: String {
        switch appState.state.goal {
        case .familiar: return "Which surah do you want to know well?"
        case .review: return "Which surah have you memorized?"
        case .meaning: return "What would you like to read?"
        }
    }

    private var surahSubtitle: String {
        switch appState.state.goal {
        case .familiar: return "You’ll read it in small pieces, over and over, until it feels familiar."
        case .review: return "Each time asks you to recall one verse. Verses you know well come back less often."
        case .meaning: return "Each time continues where you left off, with the English meaning first."
        }
    }

    private func surahChoice(_ surah: Surah, note: String?) -> some View {
        let on = appState.state.selectedSurahId == surah.id
        return Button {
            appState.selectSurah(id: surah.id)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(surah.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DesignTokens.ink)
                    Text(note.map { "\(surah.totalVerses) ayahs · \($0)" } ?? "\(surah.totalVerses) ayahs")
                        .font(DesignTokens.caption)
                        .foregroundColor(DesignTokens.muted)
                }
                Spacer()
                Text(surah.nameArabic)
                    .font(DesignTokens.arabic(24))
                    .foregroundColor(DesignTokens.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(on ? DesignTokens.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: - Shared step layout

    private static let stepCount = 4

    private func stepScaffold<Content: View>(
        current: Int,
        back: @escaping () -> Void,
        title: String,
        subtitle: String,
        continueTitle: String = "Continue",
        continueAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    CircleIconButton(systemName: "chevron.left", accessibilityLabel: "Back", action: back)
                    StepBars(current: current, total: Self.stepCount)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Step \(current) of \(Self.stepCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignTokens.accent)
                            Text(title)
                                .font(DesignTokens.title)
                                .foregroundColor(DesignTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(subtitle)
                                .font(DesignTokens.callout)
                                .foregroundColor(DesignTokens.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        content()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }

                Button(continueTitle, action: continueAction)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .background(DesignTokens.mist.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Starter surahs suggested during onboarding and in the library.
struct SuggestedSurah: Identifiable {
    let id: Int
    let note: String?

    static let starters: [SuggestedSurah] = [
        SuggestedSurah(id: 1, note: "A gentle start"),
        SuggestedSurah(id: 67, note: "Often read at night"),
        SuggestedSurah(id: 36, note: nil),
        SuggestedSurah(id: 18, note: "Often read on Fridays")
    ]

    static let library: [Int] = [67, 1, 36, 18, 55, 56, 112, 113, 114]
}

/// Pause length choice in onboarding, mapped onto the existing reading-speed setting.
enum PauseLength: CaseIterable, Hashable {
    case short, medium, long

    var label: String {
        switch self {
        case .short: return "Shorter"
        case .medium: return "Normal"
        case .long: return "Longer"
        }
    }

    var speed: ReadingSpeed {
        switch self {
        case .short: return .fast
        case .medium: return .normal
        case .long: return .slow
        }
    }
}

/// Arch shape (rounded top) used for the welcome illustration.
struct UnevenArch: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let bottomRadius: CGFloat = 24
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
