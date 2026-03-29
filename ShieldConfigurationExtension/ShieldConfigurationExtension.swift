import ManagedSettings
import ManagedSettingsUI
import UIKit

@objc(ShieldConfigurationExtension)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    /// Shared builder so app-level and category-level shields look identical.
    private func configurationForCurrentUnlockState() -> ShieldConfiguration {
        let defaults = UserDefaults(suiteName: "group.com.tilawa.app")
        let ts = defaults?.double(forKey: "tilawa.nextLockAt") ?? 0
        let nextLockAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        let isUnlocked = (nextLockAt ?? Date.distantPast) > Date()

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(
                red: 0.98, green: 0.96, blue: 0.91, alpha: 1.0
            ),
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "Tilawa",
                color: UIColor(
                    red: 0.12, green: 0.08, blue: 0.03, alpha: 1.0
                )
            ),
            subtitle: ShieldConfiguration.Label(
                text: isUnlocked
                    ? "Apps unlocked · open Tilawa to read more"
                    : "Read ayah to unlock app",
                color: UIColor(
                    red: 0.47, green: 0.36, blue: 0.21, alpha: 1.0
                )
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Read ayah to unlock app",
                color: UIColor(
                    red: 0.12, green: 0.08, blue: 0.03, alpha: 1.0
                )
            ),
            primaryButtonBackgroundColor: UIColor(
                red: 0.72, green: 0.53, blue: 0.07, alpha: 1.0
            ),
            secondaryButtonLabel: nil
        )
    }

    /// App blocked because it was chosen individually.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configurationForCurrentUnlockState()
    }

    /// App blocked because it falls under a blocked category (e.g. Social).
    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configurationForCurrentUnlockState()
    }
}
