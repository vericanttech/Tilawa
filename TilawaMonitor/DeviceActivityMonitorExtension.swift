//
//  DeviceActivityMonitorExtension.swift
//  TilawaMonitor
//
//  Created by ENRELLA TUTU on 16/03/2026.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import os

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private static let logger = Logger(subsystem: "com.tilawa.monitor", category: "DeviceActivityMonitor")
    private static let relockActivityName = DeviceActivityName("tilawa.relock")
    private static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("tilawa.shield"))
    private static let shieldTokensKey = "tilawa.shieldApplicationTokens"
    private static let shieldCategoryTokensKey = "tilawa.shieldCategoryTokens"
    private static let appGroupSuiteName = "group.com.tilawa.app"

    override func intervalDidStart(for activity: DeviceActivityName) {
        Self.logger.info("intervalDidStart for activity: \(String(describing: activity))")
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        Self.logger.info("intervalDidEnd for activity: \(String(describing: activity))")
        super.intervalDidEnd(for: activity)
        if activity == Self.relockActivityName {
            reapplyShield()
        }
    }

    /// Re-apply apps + categories from App Group (saved at last applyShield before unlock).
    private func reapplyShield() {
        guard let groupDefaults = UserDefaults(suiteName: Self.appGroupSuiteName) else {
            Self.logger.error("reapplyShield: no app group")
            return
        }
        var appSet = Set<ApplicationToken>()
        if let data = groupDefaults.data(forKey: Self.shieldTokensKey),
           let tokens = try? PropertyListDecoder().decode([ApplicationToken].self, from: data) {
            appSet = Set(tokens)
        }
        var catSet = Set<ActivityCategoryToken>()
        if let data = groupDefaults.data(forKey: Self.shieldCategoryTokensKey),
           let tokens = try? PropertyListDecoder().decode([ActivityCategoryToken].self, from: data) {
            catSet = Set(tokens)
        }
        if appSet.isEmpty, catSet.isEmpty {
            Self.logger.info("reapplyShield: no saved apps or categories")
            return
        }
        Self.store.shield.applications = appSet.isEmpty ? nil : appSet
        Self.store.shield.applicationCategories = catSet.isEmpty ? .none : .specific(catSet)
        Self.logger.info("reapplyShield: apps=\(appSet.count) categories=\(catSet.count)")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        Self.logger.info("eventDidReachThreshold event=\(String(describing: event)) activity=\(String(describing: activity))")
        super.eventDidReachThreshold(event, activity: activity)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        Self.logger.info("intervalWillStartWarning for activity: \(String(describing: activity))")
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        Self.logger.info("intervalWillEndWarning for activity: \(String(describing: activity))")
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        Self.logger.info("eventWillReachThresholdWarning event=\(String(describing: event)) activity=\(String(describing: activity))")
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
}
