import FamilyControls
import SwiftUI
import UserNotifications

/// "Today": the current surah and goal, this week's rhythm, and the paused apps.
struct HomeView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?
    @State private var showingPicker = false
    @State private var showingWirdSheet = false

    private let quran = QuranService.shared
    private var surah: Surah? { quran.surah(id: appState.state.selectedSurahId) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if Features.appPausing && remainingSeconds > 0 { unlockBanner }
                // A wird due today comes first: it's what pauses read today.
                let wirdDue = !Wird.dueToday(appState.state).isEmpty
                if wirdDue { WirdCard(appState: appState, shield: shield) { showingWirdSheet = true } }
                if let surah { nowCard(surah) }
                if !wirdDue { WirdCard(appState: appState, shield: shield) { showingWirdSheet = true } }
                ReminderCard(appState: appState)
                weekCard
                if Features.appPausing { appsCard }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.mist.ignoresSafeArea())
        .familyActivityPicker(isPresented: $showingPicker, selection: $shield.selection)
        .sheet(isPresented: $showingWirdSheet) { WirdEditorSheet(appState: appState, editing: nil) }
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
                appState.gateWird = .none
                shield.userRequestedReadingGate = true
                shield.skipGateAfterAddingApps = false
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !Features.appPausing || shield.canStartNewGate || !shield.hasAppsToShield))
            .disabled(Features.appPausing && shield.hasAppsToShield && !shield.canStartNewGate)
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
                if s.readIn == .english, let translation = verse.translation {
                    TranslationText.make(translation)
                        .font(DesignTokens.callout)
                        .foregroundColor(DesignTokens.inkSoft)
                        .lineLimit(2)
                } else if s.readIn == .transliteration {
                    Text(verse.transliteration)
                        .font(DesignTokens.serif(19))
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

// MARK: - Wird (الورد)

/// Today's wird: what's due, how far along, and a button to read it now.
struct WirdCard: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService
    let onSetUp: () -> Void

    private let quran = QuranService.shared

    var body: some View {
        let state = appState.state
        let items = Wird.activeItems(state)
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Overline(text: "My wird")
                Text("Read Al-Kahf every Friday")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                Text("Add the surahs you read regularly. On their day, your reminders go through them, a few verses at a time.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Set up my wird", action: onSetUp)
                    .buttonStyle(SoftButtonStyle(height: 48))
                    .padding(.top, 8)
            }
            .card()
        } else {
            let due = Wird.dueToday(state)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Overline(text: due.isEmpty ? "My wird" : "Today’s wird")
                    Spacer()
                    Button("Edit", action: onSetUp)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                        .buttonStyle(.plain)
                }
                if due.isEmpty {
                    nothingDue(items)
                } else {
                    ForEach(Array(due.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Rectangle().fill(DesignTokens.hairline).frame(height: 1) }
                        row(item)
                    }
                    Text("Reminders today go through this first. Tap Keep reading to finish it in one sitting.")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
    }

    private func nothingDue(_ items: [WirdItem]) -> some View {
        let next = items.compactMap { item in Wird.nextDueDay(item).map { (item, $0) } }.min { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 2) {
            Text("Nothing due today")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
            if let next, let surah = quran.surah(id: next.0.surahId) {
                Text("Next: \(surah.name) · \(dayName(next.1))")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.muted)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func row(_ item: WirdItem) -> some View {
        if let surah = quran.surah(id: item.surahId) {
            let upTo = min(Wird.upTo(appState.state, item), surah.totalVerses)
            let done = upTo >= surah.totalVerses
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(surah.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(DesignTokens.ink)
                        Text(surah.nameArabic)
                            .font(DesignTokens.arabic(16))
                            .foregroundColor(DesignTokens.muted)
                    }
                    Text(done ? "Done for today · \(surah.totalVerses) verses" : "\(upTo) of \(surah.totalVerses) verses")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.muted)
                    LineProgress(value: Double(upTo) / Double(max(1, surah.totalVerses)))
                }
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(DesignTokens.accent))
                        .accessibilityLabel("Done")
                } else {
                    let canOpen = !Features.appPausing || shield.canStartNewGate || !shield.hasAppsToShield
                    Button(upTo == 0 ? "Read" : "Continue") {
                        appState.gateWird = .item(item.id)
                        shield.userRequestedReadingGate = true
                        shield.skipGateAfterAddingApps = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(canOpen ? DesignTokens.accent : DesignTokens.outline))
                    .buttonStyle(.plain)
                    .disabled(!canOpen)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func dayName(_ date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.dateComponents([.day], from: today, to: date).day == 1 { return "tomorrow" }
        return WirdItem.dayName(WirdItem.weekday(of: date))
    }
}

/// "My wird" in Settings: the list, in reading order, plus adding and Tilawa Plus.
struct WirdSettingsList: View {
    @ObservedObject var appState: AppStateStore
    /// Called with nil to add, or the item to edit.
    let onEdit: (WirdItem?) -> Void

    private let quran = QuranService.shared

    var body: some View {
        let state = appState.state
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(state.wird.enumerated()), id: \.element.id) { index, item in
                    let surah = quran.surah(id: item.surahId)
                    let locked = !state.isPro && index >= Wird.freeLimit
                    if index > 0 { Rectangle().fill(DesignTokens.cardBorder).frame(height: 1) }
                    Button { onEdit(item) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(surah?.name ?? "")
                                    .font(.system(size: 16))
                                    .foregroundColor(locked ? DesignTokens.muted : DesignTokens.ink)
                                Text(locked ? "\(item.scheduleLabel) · needs Tilawa Plus" : item.fullLabel)
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignTokens.muted)
                            }
                            Spacer()
                            Text(surah?.nameArabic ?? "")
                                .font(DesignTokens.arabic(20))
                                .foregroundColor(locked ? DesignTokens.outline : DesignTokens.accent)
                        }
                        .padding(DesignTokens.spacingL)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if !state.wird.isEmpty { Rectangle().fill(DesignTokens.cardBorder).frame(height: 1) }
                Button { onEdit(nil) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add to my wird")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if !Wird.canAdd(state) { PlusBadge() }
                    }
                    .foregroundColor(DesignTokens.accent)
                    .padding(DesignTokens.spacingL)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if state.wird.count > 1 {
                    Text("On a day with more than one, they’re read in this order. Open one to move it.")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.muted)
                        .padding(.horizontal, DesignTokens.spacingL)
                        .padding(.bottom, 14)
                }
            }
            .background(DesignTokens.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))

            #if DEBUG
            // Purchases aren't built yet: lets us try Plus on test builds only.
            Toggle(isOn: Binding(get: { appState.state.isPro }, set: { appState.state.isPro = $0 })) {
                Text("Tilawa Plus (test builds only)")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.ink)
            }
            .tint(DesignTokens.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignTokens.streakTint))
            #endif
        }
    }
}

struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Plus")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(DesignTokens.streak)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(DesignTokens.streakTint))
    }
}

/// Adds a surah to the wird (presets or any surah, then its days), or edits one when `editing` is set.
struct WirdEditorSheet: View {
    @ObservedObject var appState: AppStateStore
    let editing: WirdItem?

    @Environment(\.dismiss) private var dismiss
    private enum Step { case presets, surahs, schedule }
    @State private var step: Step = .presets
    @State private var surahId = 18
    @State private var byWeekday = true
    @State private var weekdays: Set<Int> = [5]
    @State private var everyDays = 2
    @State private var atTime = true
    @State private var time = WirdEditorSheet.date(minutes: 9 * 60)
    @State private var query = ""
    /// The schedule step was opened from a suggestion (Back returns to the suggestions).
    @State private var fromPreset = false

    private let quran = QuranService.shared

    init(appState: AppStateStore, editing: WirdItem?) {
        self.appState = appState
        self.editing = editing
        if let editing {
            _step = State(initialValue: .schedule)
            _surahId = State(initialValue: editing.surahId)
            _byWeekday = State(initialValue: editing.everyDays == 0)
            _weekdays = State(initialValue: editing.everyDays == 0 ? editing.weekdays : [5])
            _everyDays = State(initialValue: editing.everyDays > 0 ? editing.everyDays : 2)
            _atTime = State(initialValue: editing.remindAt != nil)
            _time = State(initialValue: Self.date(minutes: editing.remindAt ?? 9 * 60))
        }
    }

    static func date(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var minutes: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if editing == nil && !Wird.canAdd(appState.state) {
                upsell
            } else {
                switch step {
                case .presets: presets
                case .surahs: surahList
                case .schedule: schedule
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(DesignTokens.surface.ignoresSafeArea())
    }

    // MARK: Steps

    private var presets: some View {
        let taken = Set(appState.state.wird.map(\.surahId))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Add to my wird")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(DesignTokens.ink)
            Text("Reminders go through it on its days.")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.muted)
                .padding(.bottom, 4)
            ForEach(Wird.presets.filter { !taken.contains($0.surahId) }, id: \.surahId) { preset in
                if let surah = quran.surah(id: preset.surahId) {
                    Button {
                        surahId = preset.surahId
                        byWeekday = preset.everyDays == 0
                        weekdays = preset.everyDays == 0 ? preset.weekdays : [5]
                        everyDays = preset.everyDays > 0 ? preset.everyDays : 2
                        atTime = true
                        time = Self.date(minutes: preset.remindAt)
                        fromPreset = true
                        step = .schedule
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.note)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(DesignTokens.ink)
                                Text("\(surah.totalVerses) verses")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignTokens.muted)
                            }
                            Spacer()
                            Text(surah.nameArabic)
                                .font(DesignTokens.arabic(20))
                                .foregroundColor(DesignTokens.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignTokens.surfaceMuted))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Choose another surah") { step = .surahs }
                .buttonStyle(TextButtonStyle())
        }
    }

    private var surahList: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? quran.surahs : quran.surahs.filter {
            $0.name.localizedCaseInsensitiveContains(q) || String($0.id) == q || $0.nameArabic.contains(q)
        }
        return VStack(alignment: .leading, spacing: 8) {
            back("Choose a surah") { step = .presets }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(DesignTokens.muted)
                TextField("Search surahs", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignTokens.track))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(list) { surah in
                        Button {
                            surahId = surah.id
                            fromPreset = false
                            step = .schedule
                        } label: {
                            HStack {
                                Text("\(surah.id)")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignTokens.muted)
                                    .frame(width: 36, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(surah.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(DesignTokens.ink)
                                    Text("\(surah.totalVerses) verses")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignTokens.muted)
                                }
                                Spacer()
                                Text(surah.nameArabic)
                                    .font(DesignTokens.arabic(18))
                                    .foregroundColor(DesignTokens.mutedStrong)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var schedule: some View {
        let surah = quran.surah(id: surahId)
        let valid = !byWeekday || !weekdays.isEmpty
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if editing == nil {
                    back(surah?.name ?? "") { step = fromPreset ? .presets : .surahs }
                } else {
                    Text(surah?.name ?? "")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DesignTokens.ink)
                }
                Text("When do you read it?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.ink)
                TilawaSegmented(options: [(true, "On certain days"), (false, "Every few days")], selection: $byWeekday)
                if byWeekday {
                    weekdayPicker
                    Text(weekdays.count == 7 ? "Every day" : WirdItem(id: 0, surahId: 0, weekdays: weekdays).scheduleLabel)
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.muted)
                } else {
                    HStack(spacing: 12) {
                        Text("Every").font(.system(size: 16)).foregroundColor(DesignTokens.ink)
                        stepper("minus", "Fewer days") { everyDays = max(1, everyDays - 1) }
                        Text("\(everyDays)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignTokens.ink)
                            .frame(width: 44)
                        stepper("plus", "More days") { everyDays = min(14, everyDays + 1) }
                        Text(everyDays == 1 ? "day" : "days").font(.system(size: 16)).foregroundColor(DesignTokens.ink)
                    }
                    Text("Starting today.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.muted)
                }
                Text("Remind me")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.ink)
                    .padding(.top, 6)
                TilawaSegmented(options: [(true, "At a set time"), (false, "With my reminders")], selection: $atTime)
                if atTime {
                    HStack {
                        Text("At").font(.system(size: 16)).foregroundColor(DesignTokens.ink)
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(DesignTokens.accent)
                        Spacer()
                    }
                    Text("A reminder at this time on its days, as well as your regular ones.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Your regular reminders go through it on its days.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.muted)
                }
                Button(editing == nil ? "Add to my wird" : "Save") { save() }
                    .buttonStyle(PrimaryButtonStyle(enabled: valid))
                    .disabled(!valid)
                if let editing {
                    if appState.state.wird.count > 1 {
                        HStack(spacing: 10) {
                            Button("Read earlier") { appState.moveWird(id: editing.id, by: -1) }
                                .buttonStyle(SoftButtonStyle(height: 48))
                            Button("Read later") { appState.moveWird(id: editing.id, by: 1) }
                                .buttonStyle(SoftButtonStyle(height: 48))
                        }
                    }
                    Button {
                        appState.removeWird(id: editing.id)
                        dismiss()
                    } label: {
                        Text("Remove from my wird")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignTokens.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var upsell: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlusBadge()
            Text("Read more with Tilawa Plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(DesignTokens.ink)
            Text("Your first wird is free. Plus lets you add as many as you like, like Al-Mulk every night or Ya-Sin every two days, each on its own days.")
                .font(.system(size: 15))
                .foregroundColor(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Reading itself is always free.")
                .font(.system(size: 15))
                .foregroundColor(DesignTokens.muted)
            Button("Coming soon") {}
                .buttonStyle(PrimaryButtonStyle(enabled: false))
                .disabled(true)
                .padding(.top, 4)
            Button("Not now") { dismiss() }
                .buttonStyle(TextButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Pieces

    private func save() {
        let days = byWeekday ? weekdays : []
        let every = byWeekday ? 0 : everyDays
        let remindAt = atTime ? minutes : nil
        if remindAt != nil {
            // A set time needs notifications, even if the regular reminders were turned down.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        if let editing {
            var item = editing
            item.weekdays = days
            item.everyDays = every
            item.remindAt = remindAt
            // A new "every N days" rhythm starts today.
            if every != editing.everyDays { item.startDay = Calendar.current.startOfDay(for: Date()) }
            appState.updateWird(item)
        } else {
            appState.addWird(surahId: surahId, weekdays: days, everyDays: every, remindAt: remindAt)
        }
        dismiss()
    }

    private func back(_ title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            CircleIconButton(systemName: "chevron.left", accessibilityLabel: "Back", background: DesignTokens.surfaceMuted, action: action)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DesignTokens.ink)
        }
        .padding(.bottom, 4)
    }

    private func stepper(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignTokens.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DesignTokens.accentTint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Seven round day toggles, Monday first.
    private var weekdayPicker: some View {
        HStack {
            ForEach(1...7, id: \.self) { day in
                let on = weekdays.contains(day)
                let name = WirdItem.dayName(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(on ? .white : DesignTokens.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(on ? DesignTokens.accent : DesignTokens.surface))
                        .overlay(Circle().stroke(on ? DesignTokens.accent : DesignTokens.outline, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(on ? .isSelected : [])
                if day < 7 { Spacer(minLength: 0) }
            }
        }
    }
}

// MARK: - Reading reminders

/// "8 AM", "Noon", "Midnight".
func hourLabel(_ hour: Int) -> String {
    switch hour {
    case 0, 24: return "Midnight"
    case 12: return "Noon"
    default: return "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")"
    }
}

/// "Every 2 hours · 8 AM – 10 PM".
func reminderSummary(_ state: AppState) -> String {
    let every = state.remindEveryHours == 1 ? "Every hour" : "Every \(state.remindEveryHours) hours"
    return "\(every) · \(hourLabel(state.remindFrom)) – \(hourLabel(state.remindUntil))"
}

/// Today: when the next reminder comes, or a way to turn them on.
struct ReminderCard: View {
    @ObservedObject var appState: AppStateStore
    @State private var notificationsAllowed = true

    var body: some View {
        let state = appState.state
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { appState.state.remindersOn }, set: { appState.state.remindersOn = $0 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders")
                        .font(DesignTokens.headline)
                        .foregroundColor(DesignTokens.ink)
                    Text(state.remindersOn ? reminderSummary(state) : "Off · a few verses every few hours")
                        .font(DesignTokens.caption)
                        .foregroundColor(DesignTokens.muted)
                }
            }
            .tint(DesignTokens.accent)
            if state.remindersOn {
                if !notificationsAllowed {
                    NotificationsBlocked()
                } else if let next = appState.nextReminderAt {
                    Text(nextLabel(next))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                }
            }
        }
        .card()
        .onAppear(perform: checkAllowed)
        .onChange(of: state.remindersOn) { _ in checkAllowed() }
    }

    private func checkAllowed() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { notificationsAllowed = settings.authorizationStatus != .denied }
        }
    }

    private func nextLabel(_ date: Date) -> String {
        let clock = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Next at \(clock)" }
        if cal.isDateInTomorrow(date) { return "Next tomorrow at \(clock)" }
        return "Next \(date.formatted(.dateTime.weekday(.wide))) at \(clock)"
    }
}

/// Notifications are switched off for Tilawa in Settings: only the person can turn them back on.
struct NotificationsBlocked: View {
    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bell.slash")
                    .foregroundColor(DesignTokens.streak)
                Text("Notifications are off for Tilawa, so reminders can’t reach you. Tap to allow them in Settings.")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignTokens.streakTint))
        }
        .buttonStyle(.plain)
    }
}

/// How often, and between which hours. Used in onboarding and Settings.
struct ReminderOptions: View {
    @ObservedObject var appState: AppStateStore

    var body: some View {
        let state = appState.state
        VStack(alignment: .leading, spacing: 12) {
            Text("How often")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
            TilawaSegmented(
                options: [(1, "1 hour"), (2, "2 hours"), (3, "3 hours"), (4, "4 hours")],
                selection: Binding(get: { appState.state.remindEveryHours }, set: { appState.state.remindEveryHours = $0 })
            )
            Text("Between")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
                .padding(.top, 4)
            hourStepper("From", state.remindFrom,
                        down: { appState.state.remindFrom = max(0, state.remindFrom - 1) },
                        up: { appState.state.remindFrom = min(state.remindUntil - 1, state.remindFrom + 1) })
            hourStepper("Until", state.remindUntil,
                        down: { appState.state.remindUntil = max(state.remindFrom + 1, state.remindUntil - 1) },
                        up: { appState.state.remindUntil = min(24, state.remindUntil + 1) })
            Text("Quiet the rest of the time. Reading in the app moves the next reminder later.")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hourStepper(_ label: String, _ hour: Int, down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(DesignTokens.muted)
            Spacer()
            roundStep("minus", "Earlier", down)
            Text(hourLabel(hour))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignTokens.ink)
                .frame(width: 92)
            roundStep("plus", "Later", up)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignTokens.surfaceMuted))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label) \(hourLabel(hour))")
    }

    private func roundStep(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(DesignTokens.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// What a reminder looks like, with the person's own next verse.
struct ReminderPreview: View {
    @ObservedObject var appState: AppStateStore
    private let quran = QuranService.shared

    var body: some View {
        let state = appState.state
        if let surah = quran.surah(id: state.selectedSurahId), !surah.chunks.isEmpty,
           let first = surah.chunks[min(state.currentChunkIndex, surah.chunks.count - 1)].ayahIds.first,
           let verse = surah.verses.first(where: { $0.id == first }) {
            let review = state.goal == .review
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DesignTokens.accent)
                        .frame(width: 20, height: 20)
                        .overlay(Text("ا").font(DesignTokens.arabic(12)).foregroundColor(.white))
                    Text("TILAWA · now")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.muted)
                }
                Text(review ? "Quick muraja’ah · \(surah.name)" : "A few verses of \(surah.name)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.ink)
                Group {
                    if review {
                        Text("Can you recall the next ayah? About 15 seconds.")
                    } else {
                        switch state.readIn {
                        case .arabic:
                            Text(verse.text)
                                .font(DesignTokens.arabic(18))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .environment(\.layoutDirection, .rightToLeft)
                        case .transliteration: Text(verse.transliteration)
                        case .english: Text(verse.translation ?? verse.transliteration)
                        }
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.inkSoft)
                .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignTokens.surface))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Example reminder")
        }
    }
}
