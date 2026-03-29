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

    /// TabView when no gate needed; GateView only after explicit request (or unlock window / post-setup).
    private var showMainTabs: Bool {
        if !shield.hasAppsToShield { return true }
        if shield.isUnlockWindowActive { return true }
        if shield.skipGateAfterAddingApps { return true }
        return !shield.userRequestedReadingGate
    }

    init() {
        // Tab bar: solid parchment, no translucency
        let parchment = UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1.0)
        let muted = UIColor(red: 0.47, green: 0.36, blue: 0.21, alpha: 1.0)
        let gold = UIColor(red: 0.72, green: 0.53, blue: 0.07, alpha: 1.0)
        UITabBar.appearance().backgroundColor = parchment
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().unselectedItemTintColor = muted
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: gold],
            for: .selected
        )
        // 1px top border
        let border = UIView()
        border.backgroundColor = UIColor(red: 0.72, green: 0.53, blue: 0.07, alpha: 0.15)
        border.translatesAutoresizingMaskIntoConstraints = false
        // Applied via appearance we can't add a subview; we'll use a SwiftUI overlay in each tab if needed, or a custom TabView style. Actually UITabBar doesn't support top border easily. We can use a custom overlay in the main content. Skip for now or add a thin divider in the tab bar area via SwiftUI. Task said "with a top border 1px rgba(180,134,11,0.15)" - I'll add an overlay in the TabView content that shows a line at the top of the tab bar. Actually the tab bar is at the bottom. So "top border" of the tab bar = the edge that touches the content, i.e. the top of the tab bar rectangle. We can't easily do that with appearance. I'll leave a note or use a custom tab bar wrapper. For now proceed without that pixel line; user can ask to add it later.
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showMainTabs {
                    ZStack(alignment: .bottom) {
                        TabView(selection: $selectedTab) {
                            HomeView(appState: appState, shield: shield)
                                .tabItem {
                                    Label("Home", systemImage: "book.pages")
                                }
                                .tag(0)

                            SetupView(appState: appState, shield: shield)
                                .tabItem {
                                    Label("Surah", systemImage: "moon.stars")
                                }
                                .tag(1)

                            SettingsView(appState: appState, shield: shield)
                                .tabItem {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                .tag(2)
                        }
                        Rectangle()
                            .fill(DesignTokens.cardBorder)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .offset(y: -49)
                    }
                } else {
                    GateView(appState: appState, shield: shield)
                }
            }
            .onAppear {
                quran.load()
                if appState.state.isFirstLaunch {
                    appState.state.isFirstLaunch = false
                    StatsService.shared.saveState(appState.state)
                    selectedTab = 1
                }
                if !hasRequestedAuth {
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
