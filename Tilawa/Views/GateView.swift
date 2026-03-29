import SwiftUI

struct GateView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService
    @State private var elapsed: Int = 0
    @State private var timer: Timer?
    @State private var chunkDuration: Int = 18
    @State private var verses: [Verse] = []

    private let quran = QuranService.shared

    var body: some View {
        let progress = chunkDuration > 0 ? min(1, Double(elapsed) / Double(chunkDuration)) : 0
        let isReady = elapsed >= chunkDuration
        let goldRule = LinearGradient(
            colors: [.clear, DesignTokens.gold.opacity(0.4), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )

        ZStack {
            // Background bleeds edge to edge
            VStack(spacing: 0) {
                DesignTokens.parchment
                DesignTokens.chromeBg
                    .frame(height: 180)
            }
            .ignoresSafeArea()

            // Content layer
            VStack(spacing: 0) {
                // 1. SURAH HEADER — fixed, never scrolls
                VStack(spacing: 0) {
                    Text(String(format: Localization.L("gate.surah_format", appState.state.language), currentSurahName))
                        .font(Font.custom("CormorantGaramond-Regular", size: 12))
                        .tracking(6)
                        .textCase(.uppercase)
                        .foregroundColor(DesignTokens.gold)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    Rectangle()
                        .fill(goldRule)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
                .background(DesignTokens.parchment)

                // 2. AYAH CONTENT — scrollable
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                            if index > 0 {
                                Rectangle()
                                    .fill(DesignTokens.gold.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.vertical, DesignTokens.spacing3xl)
                            }
                            AyahBlock(verse: verse, showTransliteration: appState.state.showTransliteration)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
                .background(DesignTokens.parchment)

                // Bottom gold rule separating parchment from chrome
                Rectangle()
                    .fill(goldRule)
                    .frame(height: 1)

                // 3. CHROME ZONE — fixed at bottom, never scrolls
                VStack(spacing: 16) {
                    HStack {
                        Text("Complete to unlock your apps")
                            .font(Font.custom("CormorantGaramond-Regular", size: 11))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(DesignTokens.chromeMuted)
                        Spacer()
                        Text("\(elapsed) / \(chunkDuration)s")
                            .font(Font.custom("CormorantGaramond-Regular", size: 11))
                            .tracking(2)
                            .foregroundColor(DesignTokens.chromeMuted)
                    }

                    TimerBar(progress: progress)

                    UnlockButton(
                        readingText: Localization.L("gate.reading", appState.state.language),
                        readyText: Localization.L("gate.continue_to_app", appState.state.language),
                        isReady: isReady,
                        action: { confirmUnlock() }
                    )

                    HStack(spacing: 0) {
                        let lang = appState.state.language
                        statItem(value: "\(appState.state.totalAyahsRead)", label: Localization.L("gate.ayahs_read", lang))
                        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 24)
                        statItem(value: "\(appState.state.streakDays)", label: Localization.L("gate.day_streak", lang))
                        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 24)
                        statItem(value: "\(appState.state.todayAyahsRead)", label: Localization.L("gate.today", lang))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .background(DesignTokens.chromeBg)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        }
        .onAppear(perform: startGate)
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private var currentSurahName: String {
        quran.surah(id: appState.state.selectedSurahId)?.name ?? "—"
    }

    private func startGate() {
        guard let surah = quran.surah(id: appState.state.selectedSurahId),
              let result = quran.currentChunk(surahId: surah.id, chunkIndex: appState.state.currentChunkIndex) else {
            verses = []
            chunkDuration = 18
            return
        }
        verses = result.verses
        // Apply reading speed: scale base duration by (multiplier / normal). Slow = longer, Fast = shorter.
        let normalMultiplier = ReadingSpeed.normal.secondsPerWordMultiplier
        let scale = appState.state.readingSpeed.secondsPerWordMultiplier / normalMultiplier
        chunkDuration = max(1, Int(round(Double(result.duration) * scale)))
        elapsed = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if elapsed < chunkDuration { elapsed += 1 }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func confirmUnlock() {
        let ayahCount = verses.count
        if let surah = quran.surah(id: appState.state.selectedSurahId) {
            appState.recordRead(ayahCount: ayahCount, surah: surah)
        }
        print("[Tilawa] GateView confirmUnlock: completeGateAndScheduleNextLock (ayahs=\(ayahCount))")
        shield.userRequestedReadingGate = false
        shield.completeGateAndScheduleNextLock()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.chromeText)
            Text(label)
                .font(Font.custom("CormorantGaramond-Regular", size: 11))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.chromeMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
