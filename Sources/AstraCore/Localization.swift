import Foundation

/// Display strings are localized independently of persistent enum values and
/// imported source texts. The original interpretation library is never translated.
public enum L10n {
    public static var language: String {
        let selection = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if selection == "ru" || selection == "en" { return selection }
        for identifier in Locale.preferredLanguages {
            let code = identifier.split(separator: "-").first.map(String.init) ?? identifier
            if code == "ru" || code == "en" { return code }
        }
        return "en"
    }

    public static var locale: Locale { Locale(identifier: language) }

    private static let englishBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }()

    /// The second argument is useful for interpolated messages and self-contained
    /// components; ordinary labels use the bundled Localizable.strings catalog.
    public static func text(_ russian: String, _ english: String? = nil) -> String {
        guard language == "en" else { return russian }
        if let english { return english }
        return englishBundle?.localizedString(forKey: russian, value: russian, table: "Localizable") ?? russian
    }
}
