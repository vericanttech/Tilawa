import SwiftUI
import UIKit
import UserNotifications

/// Handles shield “open Tilawa to read” notification: show gate when user taps the banner.
private enum TilawaNotificationGate {
    static let requestId = "tilawa.open_ayah_reader"
    static let pendingFromNotificationKey = "tilawa.pendingReadingGateFromNotification"
}

final class TilawaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = TilawaNotificationCenterDelegate.shared
        return true
    }
}

final class TilawaNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TilawaNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.notification.request.identifier == TilawaNotificationGate.requestId else { return }
        Task { @MainActor in
            let shield = ShieldService.shared
            guard shield.canStartNewGate else { return }
            UserDefaults.standard.set(true, forKey: TilawaNotificationGate.pendingFromNotificationKey)
            shield.userRequestedReadingGate = true
            shield.skipGateAfterAddingApps = false
        }
    }
}

@main
struct TilawaApp: App {
    @UIApplicationDelegateAdaptor(TilawaAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppStateStore()
    @StateObject private var shield = ShieldService.shared
    @StateObject private var quran = QuranService.shared

    @State private var selectedTab = 0
    @State private var hasRequestedAuth = false

    /// TabView when no gate needed; GateView only after explicit request, and while the done screen shows.
    private var showMainTabs: Bool {
        if shield.showingCompletion { return false }
        if !shield.hasAppsToShield { return !shield.userRequestedReadingGate }
        if shield.isUnlockWindowActive { return !shield.userRequestedReadingGate }
        if shield.skipGateAfterAddingApps { return true }
        return !shield.userRequestedReadingGate
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(red: 0.93, green: 0.945, blue: 0.937, alpha: 1) // hairline
        let teal = UIColor(red: 0.114, green: 0.42, blue: 0.384, alpha: 1)
        let muted = UIColor(red: 0.337, green: 0.396, blue: 0.416, alpha: 1)
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = muted
            layout.normal.titleTextAttributes = [.foregroundColor: muted]
            layout.selected.iconColor = teal
            layout.selected.titleTextAttributes = [.foregroundColor: teal]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !appState.state.hasCompletedOnboarding {
                    OnboardingView(appState: appState, shield: shield)
                } else if showMainTabs {
                    TabView(selection: $selectedTab) {
                        HomeView(appState: appState, shield: shield)
                            .tabItem { Label("Today", systemImage: "sun.max") }
                            .tag(0)

                        SetupView(appState: appState, shield: shield)
                            .tabItem { Label("Surahs", systemImage: "book") }
                            .tag(1)

                        ProgressTabView(appState: appState)
                            .tabItem { Label("Progress", systemImage: "chart.bar") }
                            .tag(2)

                        SettingsView(appState: appState, shield: shield)
                            .tabItem { Label("Settings", systemImage: "gearshape") }
                            .tag(3)
                    }
                    .tint(DesignTokens.accent)
                } else {
                    GateView(appState: appState, shield: shield)
                }
            }
            .onAppear {
                quran.load()
                if appState.state.hasCompletedOnboarding && !hasRequestedAuth {
                    hasRequestedAuth = true
                    Task {
                        await shield.requestAuthorization()
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    }
                }
                shield.skipGateAfterAddingApps = false
                if UserDefaults.standard.bool(forKey: TilawaNotificationGate.pendingFromNotificationKey) {
                    UserDefaults.standard.set(false, forKey: TilawaNotificationGate.pendingFromNotificationKey)
                    shield.userRequestedReadingGate = true
                }
                let hasApps = shield.hasAppsToShield
                let inUnlockWindow = shield.isUnlockWindowActive
                print("[Tilawa] onAppear: tabs=\(showMainTabs) hasApps=\(hasApps) unlockWindow=\(inUnlockWindow) requestedGate=\(shield.userRequestedReadingGate)")
                if !inUnlockWindow {
                    shield.startFullDayMonitoring()
                }
            }
            .onChange(of: scenePhase) { newValue in
                if newValue == .active {
                    shield.skipGateAfterAddingApps = false
                }
            }
        }
    }

}
