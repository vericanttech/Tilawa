import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The system screen shown over a paused app. Wording comes from the App Group,
/// written by the main app (ShieldContext) whenever the goal or surah changes.
@objc(ShieldConfigurationExtension)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let defaults = UserDefaults(suiteName: "group.com.tilawa.app")

    private let mist = UIColor(red: 0xF5 / 255, green: 0xF6 / 255, blue: 0xF2 / 255, alpha: 1)
    private let ink = UIColor(red: 0x17 / 255, green: 0x26 / 255, blue: 0x2A / 255, alpha: 1)
    private let muted = UIColor(red: 0x56 / 255, green: 0x65 / 255, blue: 0x6A / 255, alpha: 1)
    private let teal = UIColor(red: 0x1D / 255, green: 0x6B / 255, blue: 0x62 / 255, alpha: 1)

    private func configuration(appName: String?) -> ShieldConfiguration {
        let ts = defaults?.double(forKey: "tilawa.nextLockAt") ?? 0
        let isUnlocked = ts > 0 && Date(timeIntervalSince1970: ts) > Date()
        let isReview = defaults?.string(forKey: "tilawa.shield.goal") == "review"
        let detail = defaults?.string(forKey: "tilawa.shield.detail")
            ?? "Read a few verses of the Quran to open it."

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: mist,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "\(appName ?? "This app") is paused",
                color: ink
            ),
            subtitle: ShieldConfiguration.Label(
                text: isUnlocked ? "Apps open · locking again soon" : detail,
                color: muted
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: isReview ? "Review now" : "Read now",
                color: .white
            ),
            primaryButtonBackgroundColor: teal,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Not now", color: teal)
        )
    }

    /// App blocked because it was chosen individually.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration(appName: application.localizedDisplayName)
    }

    /// App blocked because it falls under a blocked category (e.g. Social).
    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configuration(appName: application.localizedDisplayName)
    }
}
