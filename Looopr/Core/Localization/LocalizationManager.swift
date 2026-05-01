import Foundation

@MainActor @Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    enum SupportedLanguage: String, CaseIterable {
        case system
        case en
        case nl
        case de
        case fr
        case es
        case esMX = "es-MX"
        case it
        case ptBR = "pt-BR"
        case ptPT = "pt-PT"

        var code: String {
            switch self {
            case .system: return Locale.current.language.languageCode?.identifier ?? "en"
            case .en: return "en"
            case .nl: return "nl"
            case .de: return "de"
            case .fr: return "fr"
            case .es: return "es"
            case .esMX: return "es-MX"
            case .it: return "it"
            case .ptBR: return "pt-BR"
            case .ptPT: return "pt-PT"
            }
        }

        var displayName: String {
            switch self {
            case .system: return "System Default"
            case .en: return "English"
            case .nl: return "Nederlands"
            case .de: return "Deutsch"
            case .fr: return "Français"
            case .es: return "Español"
            case .esMX: return "Español (México)"
            case .it: return "Italiano"
            case .ptBR: return "Português (Brasil)"
            case .ptPT: return "Português (Portugal)"
            }
        }
    }

    private(set) var currentLanguage: SupportedLanguage {
        didSet {
            guard currentLanguage != oldValue else { return }

            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "settings.appLanguage")

            // Post notification for language change
            NotificationCenter.default.post(name: Notification.Name.languageDidChange, object: nil)

            // Trigger restart alert
            showRestartAlert = true
        }
    }

    var showRestartAlert = false

    private var _localizedBundle: Bundle?

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "settings.appLanguage") ?? "system"
        self.currentLanguage = SupportedLanguage(rawValue: savedLanguage) ?? .system
    }

    /// The bundle for the currently selected language.
    /// Marked nonisolated so non-MainActor code (enums, formatters) can access it.
    nonisolated var localizedBundle: Bundle {
        let saved = UserDefaults.standard.string(forKey: "settings.appLanguage") ?? "system"
        let lang = SupportedLanguage(rawValue: saved) ?? .system

        if lang == .system {
            return Bundle.main
        }

        guard let path = Bundle.main.path(forResource: lang.code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    /// Returns the locale for the current language
    var currentLocale: Locale {
        if currentLanguage == .system {
            return Locale.current
        }
        return Locale(identifier: currentLanguage.code)
    }

    /// Change the app language
    func setLanguage(_ language: SupportedLanguage) {
        self.currentLanguage = language
    }

    /// Retrieve a localized string from the bundle
    func localizedString(_ key: String, defaultValue: String = "") -> String {
        let string = localizedBundle.localizedString(forKey: key, value: defaultValue, table: nil)
        return string.isEmpty ? defaultValue : string
    }
}

// Notification.Name.languageDidChange is defined in SettingsManager.swift
