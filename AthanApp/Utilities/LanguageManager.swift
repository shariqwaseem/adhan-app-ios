import Foundation
import Observation

@Observable
final class LanguageManager: @unchecked Sendable {
    static let shared = LanguageManager()

    private static let languageKey = "app_language"
    static let supportedLanguages = ["en", "ar", "id", "tr"]

    var currentLanguage: String {
        didSet {
            guard oldValue != currentLanguage else { return }
            UserDefaults.standard.set(currentLanguage, forKey: Self.languageKey)
            reloadBundle()
        }
    }

    /// The bundle for the selected language — use with String(localized:bundle:)
    private(set) var bundle: Bundle

    /// The locale for the selected language — use with .environment(\.locale, ...)
    /// Preserves the user's system preferences (e.g. 24-hour time) while overriding the language.
    var locale: Locale {
        var components = Locale.Components(locale: Locale.current)
        components.languageComponents = Locale.Language.Components(identifier: currentLanguage)
        return Locale(components: components)
    }

    /// Whether the current language is right-to-left (Arabic)
    var isRTL: Bool {
        currentLanguage == "ar"
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey)
        let lang: String
        if let saved, Self.supportedLanguages.contains(saved) {
            lang = saved
        } else {
            // Auto-detect from device language on first launch
            lang = Self.detectDeviceLanguage()
            UserDefaults.standard.set(lang, forKey: Self.languageKey)
        }
        self.currentLanguage = lang
        self.bundle = Self.loadBundle(for: lang)
    }

    private func reloadBundle() {
        bundle = Self.loadBundle(for: currentLanguage)
    }

    /// Loads the .lproj bundle for the given language code.
    /// Xcode compiles .xcstrings into .lproj directories inside the app bundle at build time.
    private static func loadBundle(for language: String) -> Bundle {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            return lprojBundle
        }
        // Fallback to main bundle (English)
        return Bundle.main
    }

    /// Detects the best matching language from the device's preferred languages.
    private static func detectDeviceLanguage() -> String {
        for preferred in Locale.preferredLanguages {
            let code = Locale(identifier: preferred).language.languageCode?.identifier ?? ""
            if supportedLanguages.contains(code) {
                return code
            }
        }
        return "en"
    }
}
