import Combine
import Foundation

/// Owns the app-wide content snapshot and the background content-pack refresh -
/// the native twin of App.tsx's bootstrap plus AppRoot's content subscription.
@MainActor
final class ContentStore: ObservableObject {
    @Published private(set) var snapshot: ContentSnapshot = .empty
    @Published private(set) var ready = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = 0

    private let database = AppDatabase.shared

    func bootstrap() async {
        errorMessage = nil
        ready = false
        do {
            try database.installBundledDatabaseIfNeeded()
            try database.openActive()
            apply(database.snapshot())
            ready = true
        } catch {
            print("Failed to bootstrap app", error)
            errorMessage = error.localizedDescription
            ready = false
            return
        }
        await checkForUpdates()
    }

    func retry() async {
        await bootstrap()
    }

    /// Runs whenever the app becomes active, like AppRoot's AppState listener.
    func checkForUpdates() async {
        guard ready else { return }
        let updated = await ContentUpdater.shared.check(database: database)
        if updated {
            apply(database.snapshot())
        }
    }

    private func apply(_ next: ContentSnapshot) {
        snapshot = next
        MediaLibrary.shared.setVersion(next.version)
        revision += 1
    }
}
