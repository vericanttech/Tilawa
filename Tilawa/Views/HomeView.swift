import FamilyControls
import SwiftUI

struct HomeView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService
    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?

    private let quran = QuranService.shared

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .background(DesignTokens.appBackground)

            if remainingSeconds > 0 {
                unlockBanner
                    .background(DesignTokens.appBackground)
            }

            Divider()
                .background(DesignTokens.cardBorder)
                .opacity(0)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing2xl) {
                    if let surah = quran.surah(id: appState.state.selectedSurahId) {
                        SurahCard(
                            surah: surah,
                            progressAyahs: progressAyahs(surah),
                            nextAyahPreview: nextAyahPreview(surah),
                            language: appState.state.language,
                            showTransliteration: appState.state.showTransliteration
                        )
                        .padding(.horizontal, DesignTokens.spacingXl)
                    }

                    statsRow

                    guardedAppsSection

                    unlockButtonSection
                }
                .padding(.bottom, 32)
            }
            .clipped()
        }
        .background(DesignTokens.appBackground)
        .onAppear {
            updateRemaining()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            (Text("Tilaw").foregroundColor(DesignTokens.topBarTitle) + Text("a").foregroundColor(DesignTokens.gold))
                .font(.system(size: 18))
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingXl)
        .padding(.top, DesignTokens.spacing2xl)
        .padding(.bottom, DesignTokens.spacingS)
    }

    private var unlockBanner: some View {
        HStack {
            Text("Locking in \(remainingMinutesText)")
                .font(Font.custom("CormorantGaramond-Regular", size: 13))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DesignTokens.spacingXl)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(DesignTokens.gold)
        )
        .padding(.horizontal, DesignTokens.spacingXl)
        .padding(.bottom, DesignTokens.spacingS)
    }

    private func progressAyahs(_ surah: Surah) -> Int {
        let idx = appState.state.currentChunkIndex
        guard idx > 0 else { return 0 }
        return surah.chunks.prefix(idx).flatMap(\.ayahIds).count
    }

    private func nextAyahPreview(_ surah: Surah) -> Verse? {
        let idx = appState.state.currentChunkIndex
        guard idx < surah.chunks.count else { return nil }
        guard let firstAyahId = surah.chunks[idx].ayahIds.first else { return nil }
        return surah.verses.first { $0.id == firstAyahId }
    }

    private var statsRow: some View {
        let lang = appState.state.language
        return HStack(spacing: 12) {
            StatCard(number: "\(appState.state.totalAyahsRead)", label: Localization.L("home.ayahs", lang))
            StatCard(number: "\(appState.state.streakDays)", label: Localization.L("home.streak", lang), highlight: true)
            StatCard(number: "\(appState.state.todayAyahsRead)", label: Localization.L("home.today", lang))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DesignTokens.spacingXl)
    }

    private var guardedAppsSection: some View {
        let lang = appState.state.language
        return VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text(Localization.L("home.guarded_apps", lang))
                .font(Font.custom("CormorantGaramond-Regular", size: 10))
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)
                .padding(.horizontal, DesignTokens.spacingXl)

            VStack(spacing: DesignTokens.spacingS) {
                ForEach(Array(shield.selection.applicationTokens.enumerated()), id: \.offset) { _, token in
                    AppRow(
                        isOn: shield.isAppShieldEnabled(token),
                        onToggle: { shield.setAppShieldEnabled(token, enabled: $0) }
                    ) {
                        Label(token)
                            .labelStyle(.titleAndIcon)
                    }
                }
                ForEach(Array(shield.selection.categoryTokens.enumerated()), id: \.offset) { _, token in
                    AppRow(
                        isOn: shield.isCategoryShieldEnabled(token),
                        onToggle: { shield.setCategoryShieldEnabled(token, enabled: $0) }
                    ) {
                        Label(token)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingXl)
        }
    }

    private var simulatorPreviewSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(Localization.L("home.simulator_preview", appState.state.language))
                .font(Font.custom("CormorantGaramond-Regular", size: 11))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.secondaryText)
                .padding(.horizontal, DesignTokens.spacingXl)

            Button {
                shield.userRequestedReadingGate = true
                shield.skipGateAfterAddingApps = false
            } label: {
                HStack {
                    Image(systemName: "book.closed")
                    Text(Localization.L("home.view_gate_screen", appState.state.language))
                        .font(Font.custom("CormorantGaramond-Regular", size: 16))
                }
                .foregroundColor(DesignTokens.gold)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.spacingL)
                .background(DesignTokens.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusLg).stroke(DesignTokens.gold.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.spacingXl)
        }
    }

    private var unlockButtonSection: some View {
        let canUnlock = shield.canStartNewGate
        return VStack(alignment: .center, spacing: DesignTokens.spacingM) {
            Button {
                shield.userRequestedReadingGate = true
                shield.skipGateAfterAddingApps = false
            } label: {
                Text(Localization.L("home.read_to_unlock", appState.state.language))
                    .font(Font.custom("CormorantGaramond-Regular", size: 16))
                    .foregroundColor(canUnlock ? .white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.spacingL)
                    .background(canUnlock ? DesignTokens.gold : DesignTokens.gold.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
            }
            .buttonStyle(.plain)
            .disabled(!canUnlock)
            .padding(.horizontal, DesignTokens.spacingXl)
        }
    }

    private var remainingMinutesText: String {
        let minutes = max(0, remainingSeconds / 60)
        return "\(minutes) min"
    }

    private func updateRemaining() {
        if shield.isUnlockWindowActive, let next = shield.nextLockAt {
            let remaining = Int(next.timeIntervalSinceNow)
            remainingSeconds = max(0, remaining)
        } else {
            remainingSeconds = 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            DispatchQueue.main.async {
                updateRemaining()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
