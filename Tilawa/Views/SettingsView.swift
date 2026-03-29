import SwiftUI
import FamilyControls
import ManagedSettings
struct SettingsView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var showAddAppSheet = false
    @State private var showResetConfirmation = false
    @State private var simulatorAlert = false
    @State private var languageSectionExpanded = false

    private let capsFont = Font.custom("CormorantGaramond-Regular", size: 13)
    private let sectionLabelFont = Font.custom("CormorantGaramond-Regular", size: 12)
    private var lang: Language { appState.state.language }

    var body: some View {
        VStack(spacing: 0) {
            pageTitle
                .background(DesignTokens.appBackground)

            Divider()
                .background(DesignTokens.cardBorder)
                .opacity(0)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing3xl) {
                    guardedAppsSection
                    lockScheduleSection
                    languageSection
                    readingSection
                    dataSection
                    aboutCard
                }
                .padding(.horizontal, DesignTokens.spacingXl)
                .padding(.bottom, 32)
            }
            .clipped()
        }
        .background(DesignTokens.appBackground)
        .sheet(isPresented: $showAddAppSheet) {
            addAppSheetContent
        }
        .confirmationDialog(Localization.L("settings.reset_confirm_title", lang), isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button(role: .destructive) {
                StatsService.shared.resetProgress()
                appState.reloadFromStorage()
            } label: {
                Text(Localization.L("common.reset", lang))
            }
            Button(role: .cancel) { } label: {
                Text(Localization.L("common.cancel", lang))
            }
        } message: {
            Text(Localization.L("settings.reset_confirm_message", lang))
        }
        .alert(Localization.L("settings.simulator_alert_title", lang), isPresented: $simulatorAlert) {
            Button(role: .cancel) { } label: {
                Text(Localization.L("common.ok", lang))
            }
        } message: {
            Text(Localization.L("settings.simulator_alert_message", lang))
        }
    }

    // MARK: - Page title

    private var pageTitle: some View {
        Text(Localization.L("settings.settings", lang))
            .font(.system(size: 20))
            .foregroundColor(DesignTokens.topBarTitle)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, DesignTokens.spacingXl)
            .padding(.top, DesignTokens.spacing2xl)
            .padding(.bottom, DesignTokens.spacingS)
    }

    // MARK: - Section 2 — Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(Localization.L("settings.language", lang))
                .font(sectionLabelFont)
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)

            VStack(spacing: 0) {
                // Collapsed: single row showing current language; tap to expand
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        languageSectionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: DesignTokens.spacingM) {
                        Text(lang.flag)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.displayName)
                                .font(.system(size: 17))
                                .foregroundColor(DesignTokens.primaryText)
                            Text(lang.nativeName)
                                .font(Font.custom("CormorantGaramond-Italic", size: 13))
                                .foregroundColor(DesignTokens.secondaryText)
                        }
                        Spacer()
                        Image(systemName: languageSectionExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignTokens.secondaryText)
                    }
                    .padding(DesignTokens.spacingL)
                }
                .buttonStyle(.plain)

                if languageSectionExpanded {
                    Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                    ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, lang in
                        languageRow(lang)
                        if index < Language.allCases.count - 1 {
                            Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func languageRow(_ option: Language) -> some View {
        let isSelected = appState.state.language == option
        return Button {
            appState.state.language = option
            withAnimation(.easeInOut(duration: 0.2)) {
                languageSectionExpanded = false
            }
        } label: {
            HStack(spacing: DesignTokens.spacingM) {
                Text(option.flag)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.system(size: 17))
                        .foregroundColor(DesignTokens.primaryText)
                    Text(option.nativeName)
                        .font(Font.custom("CormorantGaramond-Italic", size: 13))
                        .foregroundColor(DesignTokens.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DesignTokens.gold)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(DesignTokens.secondaryText)
                }
            }
            .padding(DesignTokens.spacingL)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 3 — Reading

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(Localization.L("settings.reading", lang))
                .font(sectionLabelFont)
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)

            VStack(spacing: 0) {
                readingSpeedRow
                Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                transliterationRow
            }
        }
    }

    // MARK: - Lock schedule

    private var lockScheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text("Lock schedule")
                .font(sectionLabelFont)
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)

            VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                HStack(spacing: DesignTokens.spacingM) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.ink)
                        .frame(width: 36, height: 36)
                        .background(DesignTokens.gold.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("After reading, lock again in")
                            .font(.system(size: 17))
                            .foregroundColor(DesignTokens.primaryText)
                        Text("Tilawa will lock your guarded apps after this delay.")
                            .font(Font.custom("CormorantGaramond-Italic", size: 13))
                            .foregroundColor(DesignTokens.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                Picker("", selection: $shield.nextSessionDelay) {
                    Text("15 minutes").tag(ShieldService.NextSessionDelay.m15)
                    Text("30 minutes").tag(ShieldService.NextSessionDelay.m30)
                    Text("60 minutes").tag(ShieldService.NextSessionDelay.m60)
                    Text("2 hours").tag(ShieldService.NextSessionDelay.h2)
                    Text("None (don’t auto-lock)").tag(ShieldService.NextSessionDelay.none)
                }
                .pickerStyle(.segmented)
            }
            .padding(DesignTokens.spacingL)
            .background(DesignTokens.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                    .stroke(DesignTokens.cardBorder, lineWidth: 1)
            )
        }
    }

    private var readingSpeedRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            HStack(spacing: DesignTokens.spacingM) {
                Image(systemName: "clock")
                    .font(.system(size: 18))
                    .foregroundColor(DesignTokens.ink)
                    .frame(width: 36, height: 36)
                    .background(DesignTokens.gold.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localization.L("settings.reading_speed", lang))
                        .font(.system(size: 17))
                        .foregroundColor(DesignTokens.primaryText)
                    Text(Localization.L("settings.reading_speed_subtitle", lang))
                        .font(Font.custom("CormorantGaramond-Italic", size: 13))
                        .foregroundColor(DesignTokens.secondaryText)
                }
                Spacer(minLength: 0)
            }
            Picker("", selection: Binding(
                get: { appState.state.readingSpeed },
                set: { appState.state.readingSpeed = $0 }
            )) {
                Text(Localization.L("settings.slow", lang)).tag(ReadingSpeed.slow)
                Text(Localization.L("settings.normal", lang)).tag(ReadingSpeed.normal)
                Text(Localization.L("settings.fast", lang)).tag(ReadingSpeed.fast)
            }
            .pickerStyle(.segmented)
        }
        .padding(DesignTokens.spacingL)
    }

    private var transliterationRow: some View {
        HStack(spacing: DesignTokens.spacingM) {
            Text("أ")
                .font(Font.custom("Lateef-Regular", size: 22))
                .foregroundColor(DesignTokens.ink)
                .frame(width: 36, height: 36)
                .background(DesignTokens.gold.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.L("settings.show_transliteration", lang))
                    .font(.system(size: 17))
                    .foregroundColor(DesignTokens.primaryText)
                Text(Localization.L("settings.transliteration_subtitle", lang))
                    .font(Font.custom("CormorantGaramond-Italic", size: 13))
                    .foregroundColor(DesignTokens.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { appState.state.showTransliteration },
                set: { appState.state.showTransliteration = $0 }
            ))
            .labelsHidden()
            .tint(DesignTokens.gold)
        }
        .padding(DesignTokens.spacingL)
    }

    // MARK: - Section 1 — Guarded apps (primary)

    private var guardedAppsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            HStack(spacing: DesignTokens.spacingS) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignTokens.gold)
                Text(Localization.L("settings.guarded_apps", lang))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.primaryText)
            }
            Text(Localization.L("settings.guarded_apps_subtitle", lang))
                .font(Font.custom("CormorantGaramond-Italic", size: 14))
                .foregroundColor(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                let appTokens = Array(shield.selection.applicationTokens)
                let catTokens = Array(shield.selection.categoryTokens)
                ForEach(Array(appTokens.enumerated()), id: \.offset) { index, token in
                    guardedAppRow(token: token)
                    let hasMoreApps = index < appTokens.count - 1
                    let hasCatsAfterApps = index == appTokens.count - 1 && !catTokens.isEmpty
                    if hasMoreApps || hasCatsAfterApps {
                        Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                    }
                }
                ForEach(Array(catTokens.enumerated()), id: \.offset) { index, token in
                    guardedCategoryRow(token: token)
                    if index < catTokens.count - 1 {
                        Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                    }
                }
                if !appTokens.isEmpty || !catTokens.isEmpty {
                    Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)
                }
                addAppRow
            }
            .padding(.top, DesignTokens.spacingS)
        }
        .padding(DesignTokens.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.gold.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                .stroke(DesignTokens.gold.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .fill(DesignTokens.gold)
                .frame(width: 3),
            alignment: .leading
        )
    }

    private func guardedAppRow(token: ApplicationToken) -> some View {
        let isOn = shield.isAppShieldEnabled(token)
        return HStack(spacing: DesignTokens.spacingM) {
            Label(token)
                .labelStyle(.titleAndIcon)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { shield.setAppShieldEnabled(token, enabled: $0) }
            ))
            .labelsHidden()
            .tint(DesignTokens.gold)
        }
        .padding(DesignTokens.spacingL)
    }

    private func guardedCategoryRow(token: ActivityCategoryToken) -> some View {
        let isOn = shield.isCategoryShieldEnabled(token)
        return HStack(spacing: DesignTokens.spacingM) {
            Label(token)
                .labelStyle(.titleAndIcon)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { shield.setCategoryShieldEnabled(token, enabled: $0) }
            ))
            .labelsHidden()
            .tint(DesignTokens.gold)
        }
        .padding(DesignTokens.spacingL)
    }

    private var addAppRow: some View {
        Button {
            if Device.isSimulator {
                simulatorAlert = true
            } else {
                showAddAppSheet = true
            }
        } label: {
            HStack(spacing: DesignTokens.spacingM) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.gold)
                Text(Localization.L("settings.add_app", lang))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(DesignTokens.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.gold)
            }
            .padding(DesignTokens.spacingL)
            .background(DesignTokens.gold.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .stroke(DesignTokens.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var addAppSheetContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(DesignTokens.secondaryText.opacity(0.6))
                    .frame(width: 36, height: 5)
                    .padding(.top, DesignTokens.spacingM)

                Text(Localization.L("settings.choose_apps_to_guard", lang))
                    .font(capsFont)
                    .tracking(0.22)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.primaryText)
                    .padding(.top, DesignTokens.spacingL)
                    .padding(.bottom, DesignTokens.spacingM)

                FamilyActivityPicker(selection: $shield.selection)
                    .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.appBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        print("[Tilawa] Settings Done: applyShield + startFullDayMonitoring (stay on TabView, no gate)")
                        shield.applyShield()
                        shield.startFullDayMonitoring()
                        shield.skipGateAfterAddingApps = true
                        showAddAppSheet = false
                    } label: {
                        Text(Localization.L("common.done", lang))
                    }
                    .buttonStyle(.plain)
                    .font(Font.custom("CormorantGaramond-Regular", size: 16))
                    .foregroundColor(DesignTokens.gold)
                }
            }
        }
    }

    // MARK: - Section 4 — Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(Localization.L("settings.data", lang))
                .font(sectionLabelFont)
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)

            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: DesignTokens.spacingM) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.danger)
                        .frame(width: 36, height: 36)
                        .background(DesignTokens.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
                        .overlay(RoundedRectangle(cornerRadius: DesignTokens.radiusMd).stroke(DesignTokens.dangerBorder, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localization.L("settings.reset_progress", lang))
                            .font(.system(size: 17))
                            .foregroundColor(DesignTokens.danger)
                        Text(Localization.L("settings.reset_progress_subtitle", lang))
                            .font(Font.custom("CormorantGaramond-Italic", size: 13))
                            .foregroundColor(DesignTokens.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.danger)
                }
                .padding(DesignTokens.spacingL)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - About card

    private var aboutCard: some View {
        VStack(spacing: DesignTokens.spacingL) {
            (Text("Tilaw").foregroundColor(DesignTokens.primaryText) + Text("a").foregroundColor(DesignTokens.gold))
                .font(.system(size: 24))

            Text(String(format: Localization.L("settings.version_format", lang), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"))
                .font(capsFont)
                .tracking(0.22)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.secondaryText)

            Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)

            attributionText

            Rectangle().fill(DesignTokens.cardBorder).frame(height: 1)

            Link(Localization.L("settings.privacy_policy", lang), destination: URL(string: "https://tilawa.app/privacy")!)
                .font(.system(size: 15))
                .foregroundColor(DesignTokens.gold)
                .frame(maxWidth: .infinity)
        }
        .padding(DesignTokens.spacingXl)
        .frame(maxWidth: .infinity)
    }

    private var attributionText: some View {
        let italic14 = Font.custom("CormorantGaramond-Italic", size: 14)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Localization.L("settings.about_quran_from", lang))
                    .font(italic14)
                    .foregroundColor(DesignTokens.secondaryText)
                Link("quran-json", destination: URL(string: "https://github.com/risan/quran-json")!)
                    .font(italic14)
                    .foregroundColor(DesignTokens.gold)
                Text(Localization.L("settings.about_uthmanic", lang))
                    .font(italic14)
                    .foregroundColor(DesignTokens.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Localization.L("settings.about_transliteration_from", lang))
                    .font(italic14)
                    .foregroundColor(DesignTokens.secondaryText)
                Link("tanzil.net", destination: URL(string: "https://tanzil.net")!)
                    .font(italic14)
                    .foregroundColor(DesignTokens.gold)
            }

            Text(Localization.L("settings.about_made_with", lang))
                .font(italic14)
                .foregroundColor(DesignTokens.secondaryText)
        }
        .lineSpacing(1.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Language display helpers

extension Language {
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        case .arabic: return "🇸🇦"
        }
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "French"
        case .arabic: return "Arabic"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .arabic: return "العربية"
        }
    }
}

#Preview {
    SettingsView(appState: AppStateStore(), shield: ShieldService.shared)
}
