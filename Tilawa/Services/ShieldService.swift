import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class ShieldService: ObservableObject {
    static let shared = ShieldService()

    enum NextSessionDelay: String, CaseIterable, Codable {
        case m15, m30, m60, h2, none

        var seconds: TimeInterval? {
            switch self {
            case .m15: return 15 * 60
            case .m30: return 30 * 60
            case .m60: return 60 * 60
            case .h2:  return 2 * 60 * 60
            case .none: return nil
            }
        }
    }

    /// Named store so DeviceActivity schedule can control when it is enforced.
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("tilawa.shield"))

    @Published var isAuthorized = false
    @Published var selection = FamilyActivitySelection()
    @Published var isShieldActive = false

    /// When true, show TabView instead of GateView right after user adds apps (setup only).
    @Published var skipGateAfterAddingApps = false

    /// When true, user chose to open the reading gate (Home button or shield notification). Gate is not shown on a normal app open.
    @Published var userRequestedReadingGate = false

    /// Tokens the user has turned off in settings (still in selection, but not shielded).
    @Published var excludedApplicationTokens: Set<ApplicationToken> = []
    @Published var excludedCategoryTokens: Set<ActivityCategoryToken> = []

    /// User-selected delay before the next automatic lock kicks in.
    @Published var nextSessionDelay: NextSessionDelay = .m15

    /// When the next automatic lock should occur. While this is a future time
    /// and the shield is not active, apps are considered "unlocked until nextLockAt".
    @Published var nextLockAt: Date? = nil

    private let selectionKey = "tilawa.familyActivitySelection"
    private let excludedTokensKey = "tilawa.excludedApplicationTokens"
    private let excludedCategoryTokensKey = "tilawa.excludedCategoryTokens"
    private let shieldTokensKey = "tilawa.shieldApplicationTokens"
    private let shieldCategoryTokensKey = "tilawa.shieldCategoryTokens"
    private let unlockExpiryKey = "unlockExpiry" // legacy, kept for migration
    private let nextSessionDelayKey = "tilawa.nextSessionDelay"
    private let nextLockAtKey = "tilawa.nextLockAt"

    private let activityName = DeviceActivityName("tilawa.blocking")
    /// Used for the "unlock window" schedule: interval from now to now+10min; extension re-locks in intervalDidEnd.
    private let relockActivityName = DeviceActivityName("tilawa.relock")
    private let center = DeviceActivityCenter()

    /// Full-day schedule: blocking active from 00:00 to 23:59, repeats daily.
    private var fullDaySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )
    }

    private let logPrefix = "[Tilawa Shield]"

    init() {
        loadSelection()
    }

    func requestAuthorization() async {
        #if targetEnvironment(simulator)
        isAuthorized = false
        return
        #endif
        let center = AuthorizationCenter.shared
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    private var effectiveApplicationTokens: Set<ApplicationToken> {
        selection.applicationTokens.subtracting(excludedApplicationTokens)
    }

    private var effectiveCategoryTokens: Set<ActivityCategoryToken> {
        selection.categoryTokens.subtracting(excludedCategoryTokens)
    }

    func applyShield() {
        let toShieldApps = effectiveApplicationTokens
        let toShieldCats = effectiveCategoryTokens

        store.shield.applications = toShieldApps.isEmpty ? nil : toShieldApps
        store.shield.applicationCategories = toShieldCats.isEmpty
            ? ShieldSettings.ActivityCategoryPolicy.none
            : .specific(toShieldCats)

        isShieldActive = !toShieldApps.isEmpty || !toShieldCats.isEmpty
        saveShieldSnapshotToAppGroup(apps: toShieldApps, categories: toShieldCats)
        saveSelection()

        if toShieldApps.isEmpty, toShieldCats.isEmpty {
            print("\(logPrefix) applyShield: nothing to shield (no apps/categories), clearing monitoring")
            center.stopMonitoring([activityName])
            center.stopMonitoring([relockActivityName])
        } else {
            print("\(logPrefix) applyShield: \(toShieldApps.count) app(s), \(toShieldCats.count) categor\(toShieldCats.count == 1 ? "y" : "ies")")
        }
    }

    func setAppShieldEnabled(_ token: ApplicationToken, enabled: Bool) {
        if enabled {
            excludedApplicationTokens.remove(token)
        } else {
            excludedApplicationTokens.insert(token)
        }
        applyShield()
    }

    func setCategoryShieldEnabled(_ token: ActivityCategoryToken, enabled: Bool) {
        if enabled {
            excludedCategoryTokens.remove(token)
        } else {
            excludedCategoryTokens.insert(token)
        }
        applyShield()
    }

    func isAppShieldEnabled(_ token: ApplicationToken) -> Bool {
        !excludedApplicationTokens.contains(token)
    }

    func isCategoryShieldEnabled(_ token: ActivityCategoryToken) -> Bool {
        !excludedCategoryTokens.contains(token)
    }

    /// True when at least one app (not excluded) or category (not excluded) should be shielded.
    var hasAppsToShield: Bool {
        !effectiveApplicationTokens.isEmpty || !effectiveCategoryTokens.isEmpty
    }

    /// True when we are in an "unlocked until next lock" window:
    /// there is a future nextLockAt and the shield is currently inactive.
    var isUnlockWindowActive: Bool {
        guard let nextLockAt, !isShieldActive else { return false }
        return nextLockAt > Date()
    }

    /// Whether the user is allowed to start a new reading gate session.
    /// Only possible when there are guarded apps and we're not currently in
    /// an unlock window.
    var canStartNewGate: Bool {
        hasAppsToShield && !isUnlockWindowActive
    }

    func removeShield() {
        print("\(logPrefix) removeShield: clearing store (apps/categories unlock)")
        store.shield.applications = nil
        store.shield.applicationCategories = .none
        isShieldActive = false
    }

    /// Start monitoring with a full-day schedule so the shield is enforced 24/7.
    func startFullDayMonitoring() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("\(logPrefix) startFullDayMonitoring: skipped (authorizationStatus != .approved)")
            return
        }
        let apps = effectiveApplicationTokens
        let cats = effectiveCategoryTokens
        guard !apps.isEmpty || !cats.isEmpty else {
            print("\(logPrefix) startFullDayMonitoring: skipped (nothing to shield)")
            return
        }
        print("\(logPrefix) startFullDayMonitoring: full-day schedule (\(apps.count) apps, \(cats.count) categories)")
        applyShield()
        // When we intentionally lock apps for the full day, clear any pending
        // "next lock" so Home and the shield UI don't show a future lock time.
        nextLockAt = nil
        center.stopMonitoring([activityName, relockActivityName])
        do {
            try center.startMonitoring(activityName, during: fullDaySchedule)
            print("\(logPrefix) startFullDayMonitoring: started successfully")
        } catch {
            print("\(logPrefix) startFullDayMonitoring: error \(error)")
        }
    }

    /// Schedule the next automatic lock based on the selected delay.
    /// When delay is `.none`, no auto-lock is scheduled.
    func scheduleNextLock(from date: Date = Date()) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("\(logPrefix) scheduleNextLock: skipped (authorizationStatus != .approved)")
            return
        }
        guard let seconds = nextSessionDelay.seconds else {
            print("\(logPrefix) scheduleNextLock: .none selected, clearing nextLockAt and stopping relock monitoring")
            nextLockAt = nil
            center.stopMonitoring([relockActivityName])
            saveSelection()
            return
        }

        let lockTime = date.addingTimeInterval(seconds)
        nextLockAt = lockTime

        let cal = Calendar.current
        let startComponents = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: lockTime)
        let endComponents = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: lockTime.addingTimeInterval(5 * 60))
        let relockSchedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false,
            warningTime: nil
        )

        center.stopMonitoring([relockActivityName])
        do {
            try center.startMonitoring(relockActivityName, during: relockSchedule)
            print("\(logPrefix) scheduleNextLock: scheduled lock at \(lockTime)")
        } catch {
            print("\(logPrefix) scheduleNextLock: error \(error)")
        }
        saveSelection()
    }

    /// Called when the user finishes the reading gate. Immediately unlocks
    /// guarded apps and schedules the next automatic lock according to the
    /// selected delay.
    func completeGateAndScheduleNextLock() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("\(logPrefix) completeGateAndScheduleNextLock: skipped (authorizationStatus != .approved)")
            return
        }
        print("\(logPrefix) completeGateAndScheduleNextLock: removing shield and scheduling next lock")
        removeShield()
        center.stopMonitoring([activityName, relockActivityName])
        scheduleNextLock()
    }

    /// Legacy API kept for migration; now just delegates to the new behavior.
    func unlockForTenMinutes() {
        print("\(logPrefix) unlockForTenMinutes (legacy): delegating to completeGateAndScheduleNextLock()")
        completeGateAndScheduleNextLock()
    }

    func saveSelection() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.tilawa.app") else { return }
        do {
            let data = try PropertyListEncoder().encode(selection)
            groupDefaults.set(data, forKey: selectionKey)
            let excludedData = try PropertyListEncoder().encode(Array(excludedApplicationTokens))
            groupDefaults.set(excludedData, forKey: excludedTokensKey)
            let excludedCat = try PropertyListEncoder().encode(Array(excludedCategoryTokens))
            groupDefaults.set(excludedCat, forKey: excludedCategoryTokensKey)
            groupDefaults.set(nextSessionDelay.rawValue, forKey: nextSessionDelayKey)
            if let nextLockAt {
                groupDefaults.set(nextLockAt.timeIntervalSince1970, forKey: nextLockAtKey)
            } else {
                groupDefaults.removeObject(forKey: nextLockAtKey)
            }
        } catch {
            print("\(logPrefix) saveSelection: encode error \(error)")
        }
    }

    func loadSelection() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.tilawa.app"),
              let data = groupDefaults.data(forKey: selectionKey) else { return }
        do {
            selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            if let excludedData = groupDefaults.data(forKey: excludedTokensKey),
               let arr = try? PropertyListDecoder().decode([ApplicationToken].self, from: excludedData) {
                excludedApplicationTokens = Set(arr)
            }
            if let excludedCatData = groupDefaults.data(forKey: excludedCategoryTokensKey),
               let arr = try? PropertyListDecoder().decode([ActivityCategoryToken].self, from: excludedCatData) {
                excludedCategoryTokens = Set(arr)
            }
            if let rawDelay = groupDefaults.string(forKey: nextSessionDelayKey),
               let delay = NextSessionDelay(rawValue: rawDelay) {
                nextSessionDelay = delay
            }
            let ts = groupDefaults.double(forKey: nextLockAtKey)
            if ts > 0 {
                nextLockAt = Date(timeIntervalSince1970: ts)
            } else {
                nextLockAt = nil
            }
        } catch {
            print("\(logPrefix) loadSelection: decode error \(error)")
        }
    }

    private func saveShieldSnapshotToAppGroup(apps: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>) {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.tilawa.app") else { return }
        if apps.isEmpty {
            groupDefaults.removeObject(forKey: shieldTokensKey)
        } else if let data = try? PropertyListEncoder().encode(Array(apps)) {
            groupDefaults.set(data, forKey: shieldTokensKey)
        }
        if categories.isEmpty {
            groupDefaults.removeObject(forKey: shieldCategoryTokensKey)
        } else if let data = try? PropertyListEncoder().encode(Array(categories)) {
            groupDefaults.set(data, forKey: shieldCategoryTokensKey)
        }
    }
}
