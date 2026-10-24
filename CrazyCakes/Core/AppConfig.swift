import Foundation

/// Runtime configuration - the native equivalent of the React Native app's
/// EXPO_PUBLIC_* environment values.
///
/// Values are read from AppConfig.plist in the app bundle (see
/// CrazyCakes/Resources/AppConfig.plist) so they can be changed without touching code,
/// then from the generated Info.plist, and finally fall back to the defaults below.
enum AppConfig {
    /// The published mobile content pack, matching .env.example in the React Native project.
    static let defaultContentBaseURL = "https://ashrafkandil.github.io/CrazyCakesMobile/mobile-content"
    static let defaultGeminiBaseURL = "https://generativelanguage.googleapis.com"

    private static let plist: [String: Any] = {
        guard let url = BundleResource.url(named: "AppConfig", ext: "plist"),
              let data = try? Data(contentsOf: url),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dictionary
    }()

    private static func value(_ key: String) -> String? {
        let raw = (plist[key] as? String) ?? (Bundle.main.object(forInfoDictionaryKey: key) as? String)
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// EXPO_PUBLIC_MOBILE_CONTENT_URL
    static var contentBaseURL: String {
        let base = value("MobileContentURL") ?? defaultContentBaseURL
        return base.hasSuffix("/") ? String(base.dropLast()) : base
    }

    /// EXPO_PUBLIC_GEMINI_API_KEY
    static var geminiAPIKey: String {
        value("GeminiAPIKey") ?? ""
    }

    /// EXPO_PUBLIC_GEMINI_MODEL (optional override of the model fallback chain).
    static var geminiModel: String? {
        value("GeminiModel")
    }

    /// EXPO_PUBLIC_GEMINI_API_BASE_URL
    static var geminiBaseURL: String {
        let base = value("GeminiAPIBaseURL") ?? defaultGeminiBaseURL
        return base.hasSuffix("/") ? String(base.dropLast()) : base
    }
}
