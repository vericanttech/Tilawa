import Foundation

/// Returns the localized string for the given key in the given language.
/// Uses the app's in-app language setting (not the device locale).
enum Localization {
    static func L(_ key: String, _ language: Language) -> String {
        let english = englishString(key)
        guard let path = Bundle.main.path(forResource: language.localeCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return english
        }
        // Fall back to English when a key has not been translated yet.
        return NSLocalizedString(key, bundle: bundle, value: english, comment: "")
    }

    private static func englishString(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }

}
