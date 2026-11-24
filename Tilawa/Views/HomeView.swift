import FamilyControls
import SwiftUI

/// "Today": the current surah and goal, this week's rhythm, and the paused apps.
struct HomeView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?
    @State private var showingPicker = false

    private let quran = QuranService.shared
    private var surah: Surah? { quran.surah(id: appState.state.selectedSurahId) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if remainingSeconds > 0 { unlockBanner }
                if let surah { nowCard(surah) }
                weekCard
                appsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.mist.ignoresSafeArea())
        .familyActivityPicker(isPresented: $showingPicker, selection: $shield.selection)
        .onChange(of: shield.selection) { _ in
            shield.saveSelection()
            shield.applyShield()
            shield.startFullDayMonitoring()
        }
        .onAppear {
            updateRemaining()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Assalamu alaikum")
                    .font(DesignTokens.callout)
                    .foregroundColor(DesignTokens.muted)
                Text("Today")
                    .font(DesignTokens.largeTitle)
                    .foregroundColor(DesignTokens.ink)
            }
            Spacer()
            if appState.state.streakDays > 0 {
                StreakPill(text: "\(appState.state.streakDays)")
                    .accessibilityLabel("\(appState.state.streakDays)-day streak")
            }
        }
    }

    private var unlockBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.open")
                .font(.system(size: 14, weight: .semibold))
            Text("Apps open · locking in \(max(1, remainingSeconds / 60)) min")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .foregroundColor(DesignTokens.onAccentTint)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.accentTint))
    }

    // MARK: Now card

    private func nowCard(_ surah: Surah) -> some View {
        let goal = appState.state.goal
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Overline(text: goal.nowLabel)
                    Text(surah.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(DesignTokens.ink)
                    Text(subtitle(surah))
                        .font(DesignTokens.callout)
                        .foregroundColor(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                RingProgress(value: progress(surah))
                    .accessibilityLabel("\(Int(progress(surah) * 100)) percent")
            }

            upNext(surah)

            Button(goal.actionTitle) {
                shield.userRequestedReadingGate = true
                shield.skipGateAfterAddingApps = false
            }
            .buttonStyle(PrimaryButtonStyle(enabled: shield.canStartNewGate || !shield.hasAppsToShield))
            .disabled(shield.hasAppsToShield && !shield.canStartNewGate)
        }
        .card()
    }

    private func subtitle(_ surah: Surah) -> String {
        let s = appState.state
        switch s.goal {
        case .review:
            let strong = StatsService.shared.strongVerseCount(in: surah, state: s)
            return "\(strong) of \(surah.totalVerses) verses strong"
        case .familiar:
            let pass = s.timesThroughSurah + 1
            return "\(Ordinal.string(pass)) time through · \(versesRead(surah)) of \(surah.totalVerses) verses"
        case .meaning:
            return "\(versesRead(surah)) of \(surah.totalVerses) verses, with meaning"
        }
    }

    private func versesRead(_ surah: Surah) -> Int {
        let idx = min(appState.state.currentChunkIndex, surah.chunks.count)
        return surah.chunks.prefix(idx).reduce(0) { $0 + $1.ayahIds.count }
    }

    private func progress(_ surah: Surah) -> Double {
        guard surah.totalVerses > 0 else { return 0 }
        if appState.state.goal == .review {
            return Double(StatsService.shared.strongVerseCount(in: surah, state: appState.state)) / Double(surah.totalVerses)
        }
        return Double(versesRead(surah)) / Double(surah.totalVerses)
    }

    @ViewBuilder
    private func upNext(_ surah: Surah) -> some View {
        let s = appState.state
        if s.goal == .review {
            let due = StatsService.shared.versesDueToday(in: surah, state: s).prefix(4)
            VStack(alignment: .leading, spacing: 10) {
                Text(due.isEmpty ? "Up next" : "Due today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.muted)
                HStack(spacing: 8) {
                    if due.isEmpty, let next = StatsService.shared.nextReviewVerse(in: surah, state: s) {
                        InfoPill(text: "Ayah \(next.id)")
                    } else {
                        ForEach(Array(due), id: \.id) { verse in
                            InfoPill(text: "Ayah \(verse.id)")
                        }
                    }
                }
            }
        } else if let verse = nextVerse(surah) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Up next · ayah \(verse.id)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.muted)
                if (s.meaningFirst || s.goal == .meaning), let translation = verse.translation {
                    Text(translation)
                        .font(DesignTokens.callout)
                        .foregroundColor(DesignTokens.inkSoft)
                        .lineLimit(2)
                } else {
                    Text(verse.text)
                        .font(DesignTokens.arabic(22))
                        .foregroundColor(DesignTokens.inkSoft)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignTokens.radiusLg, style: .continuous).fill(DesignTokens.surfaceMuted))
        }
    }

    private func nextVerse(_ surah: Surah) -> Verse? {
        let idx = appState.state.currentChunkIndex
        guard idx < surah.chunks.count, let first = surah.chunks[idx].ayahIds.first else { return nil }
        return surah.verses.first { $0.id == first }
    }

    // MARK: This week

    private var weekCard: some View {
        let days = StatsService.shared.history(days: 7, state: appState.state)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let symbols = cal.veryShortWeekdaySymbols
        let total = days.reduce(0, +)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This week")
                    .font(DesignTokens.headline)
                    .foregroundColor(DesignTokens.ink)
                Spacer()
                Text(total == 1 ? "1 verse" : "\(total) verses")
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.muted)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let date = cal.date(byAdding: .day, value: i - 6, to: today) ?? today
                    let weekday = cal.component(.weekday, from: date) - 1
                    let isToday = i == 6
                    VStack(spacing: 8) {
                        Text(symbols[weekday])
                            .font(.system(size: 12, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? DesignTokens.ink : DesignTokens.muted)
                        ZStack {
                            Circle()
                                .fill(days[i] > 0 ? DesignTokens.accent : DesignTokens.track)
                            if days[i] > 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(isToday ? DesignTokens.accent : .clear, lineWidth: 2).padding(-3))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(isToday ? "Today" : symbols[weekday]): \(days[i] > 0 ? "read" : "not yet")")
                }
            }
        }
        .card()
    }

    // MARK: Apps

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause my apps")
                        .font(DesignTokens.headline)
                        .foregroundColor(DesignTokens.ink)
                    Text(shield.hasAppsToShield
                         ? "They open after a few verses."
                         : "Choose apps to pause until you read.")
                        .font(DesignTokens.caption)
                        .foregroundColor(DesignTokens.muted)
                }
                Spacer()
                Button(shield.hasAppsToShield ? "Edit" : "Choose") { showingPicker = true }
                    .buttonStyle(TextButtonStyle())
            }

            if shield.hasAppsToShield {
                VStack(spacing: 0) {
                    ForEach(Array(shield.selection.applicationTokens.enumerated()), id: \.offset) { _, token in
                        appRow(isOn: shield.isAppShieldEnabled(token),
                               set: { shield.setAppShieldEnabled(token, enabled: $0) }) {
                            Label(token).labelStyle(.titleAndIcon)
                        }
                    }
                    ForEach(Array(shield.selection.categoryTokens.enumerated()), id: \.offset) { _, token in
                        appRow(isOn: shield.isCategoryShieldEnabled(token),
                               set: { shield.setCategoryShieldEnabled(token, enabled: $0) }) {
                            Label(token).labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func appRow<L: View>(isOn: Bool, set: @escaping (Bool) -> Void, @ViewBuilder label: () -> L) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) {
            label()
                .font(DesignTokens.callout)
                .foregroundColor(DesignTokens.ink)
        }
        .tint(DesignTokens.accent)
        .padding(.vertical, 8)
    }

    // MARK: Timer

    private func updateRemaining() {
        if shield.isUnlockWindowActive, let next = shield.nextLockAt {
            remainingSeconds = max(0, Int(next.timeIntervalSinceNow))
        } else {
            remainingSeconds = 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 30, repeats: true) { _ in
            DispatchQueue.main.async { updateRemaining() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
