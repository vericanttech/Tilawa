import Foundation

/// Returns the localized string for the given key in the given language.
/// Uses the app's in-app language setting (not the device locale).
enum Localization {
    static func L(_ key: String, _ language: Language) -> String {
        guard let path = Bundle.main.path(forResource: language.localeCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }

}
