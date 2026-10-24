import Combine
import Foundation

/// Holds the quote details Sprinkles gathers - the native twin of
/// src/assistant/quoteDraft.ts, where the React Native app keeps a module-level store
/// because there is no sessionStorage.
final class QuoteDraftStore: ObservableObject {
    static let shared = QuoteDraftStore()

    enum Field: String, CaseIterable {
        case name
        case email
        case phone
        case eventType
        case eventDate
        case servings
        case location
        case theme
    }

    @Published private(set) var values: [String: String] = [:]
    @Published private(set) var revision = 0

    private init() {}

    func read() -> [String: String] {
        values
    }

    /// Merges new details into the saved draft and notifies an open contact form.
    func write(_ patch: [String: String]) {
        var next = values
        for field in Field.allCases {
            guard let value = patch[field.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            next[field.rawValue] = value
        }
        values = next
        revision += 1
    }

    func clear() {
        values = [:]
        revision += 1
    }
}
