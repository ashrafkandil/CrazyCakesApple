import Foundation
import SQLite3

/// Theme model matching the database schema
struct Theme: Identifiable, Hashable {
    let id: Int
    let name: String
    let primaryColor: String
    let primaryForeground: String
    let secondaryColor: String
    let secondaryForeground: String
    let background: String
    let surface: String
    let muted: String
    let mutedForeground: String
    let border: String
    let gold: String
    let overlay: String
    let blush: String
    let isDefault: Bool
    let sort: Int
}

/// Theme repository for loading and managing themes from the database
final class ThemeRepository {
    static let shared = ThemeRepository()

    private var cachedThemes: [Theme] = []
    private var defaultTheme: Theme?
    private let queue = DispatchQueue(label: "com.marwacrazycakes.theme.repository")

    private init() {}

    /// Load themes from the database
    func loadThemes() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let db = try self.openDatabase()
                    defer { sqlite3_close(db) }

                    var themes: [Theme] = []
                    var defaultTheme: Theme?

                    var statement: OpaquePointer?
                    let sql = """
                        SELECT id, name, primary_color, primary_foreground, secondary_color, secondary_foreground,
                               background, surface, muted, muted_foreground, border, gold, overlay, blush, is_default, sort
                        FROM themes ORDER BY sort, id
                        """

                    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                        continuation.resume(throwing: ThemeError.failedToPrepareStatement)
                        return
                    }
                    defer { sqlite3_finalize(statement) }

                    var themes: [Theme] = []
                    var defaultTheme: Theme?

                    while sqlite3_step(statement) == SQLITE_ROW {
                        let id = Int(sqlite3_column_int64(statement, 0))
                        let name = String(cString: sqlite3_column_text(statement, 1))
                        let primaryColor = String(cString: sqlite3_column_text(statement, 2))
                        let primaryForeground = String(cString: sqlite3_column_text(statement, 3))
                        let secondaryColor = String(cString: sqlite3_column_text(statement, 4))
                        let secondaryForeground = String(cString: sqlite3_column_text(statement, 5))
                        let background = String(cString: sqlite3_column_text(statement, 6))
                        let surface = String(cString: sqlite3_column_text(statement, 7))
                        let muted = String(cString: sqlite3_column_text(statement, 7))
                        let mutedForeground = String(cString: sqlite3_column_text(statement, 8))
                        let border = String(cString: sqlite3_column_text(statement, 9))
                        let gold = String(cString: sqlite3_column_text(statement, 10))
                        let overlay = String(cString: sqlite3_column_text(statement, 11))
                        let blush = String(cString: sqlite3_column_text(statement, 12))
                        let isDefault = sqlite3_column_int(statement, 13) == 1
                        let sort = Int(sqlite3_column_int(statement, 14))

                        let theme = Theme(
                            id: id,
                            name: name,
                            primaryColor: primaryColor,
                            primaryForeground: primaryForeground,
                            secondaryColor: secondaryColor,
                            secondaryForeground: secondaryForeground,
                            background: background,
                            surface: surface,
                            muted: muted,
                            mutedForeground: mutedForeground,
                            border: border,
                            gold: gold,
                            overlay: overlay,
                            blush: blush,
                            isDefault: isDefault,
                            sort: sort
                        )

                        themes.append(theme)
                        if theme.isDefault {
                            defaultTheme = theme
                        }
                    }

                    self.cachedThemes = themes
                    self.defaultTheme = defaultTheme ?? themes.first
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get all themes
    var themes: [Theme] {
        return queue.sync { cachedThemes }
    }

    /// Get the default theme
    var defaultTheme: Theme? {
        return queue.sync { defaultTheme }
    }

    /// Set a theme as default
    func setDefaultTheme(id: Int) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let db = try self.openDatabase()
                    defer { sqlite3_close(db) }

                    // Reset all themes to not default
                    try Self.execute(db, sql: "UPDATE themes SET is_default = 0")

                    // Set the selected theme as default
                    let result = try Self.execute(db, sql: "UPDATE themes SET is_default = 1 WHERE id = ?", params: [id])

                    if result > 0 {
                        // Refresh cache
                        try self.loadThemes()
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ThemeError.themeNotFound)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get all themes
    var allThemes: [Theme] {
        return queue.sync { cachedThemes }
    }

    // MARK: - Private helpers

    private func openDatabase() throws -> OpaquePointer {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbURL = appSupport.appendingPathComponent("Database/crazy-cakes.db")

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(dbURL.path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let handle { sqlite3_close(handle) }
            throw ThemeError.openFailed(message)
        }
        sqlite3_busy_timeout(handle, 5000)
        return handle
    }

    static func execute(_ db: OpaquePointer, sql: String, params: [Any] = []) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ThemeError.failedToPrepareStatement
        }
        defer { sqlite3_finalize(statement) }

        for (index, param) in params.enumerated() {
            let position = Int32(index + 1)
            switch param {
            case let value as Int:
                sqlite3_bind_int64(statement, position, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, position, value)
            case let value as String:
                sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
            default:
                sqlite3_bind_null(statement, position)
            }
        }

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(sqlite3_db_handle(statement!)))
            throw ThemeError.executionFailed(message)
        }
        return sqlite3_changes(sqlite3_db_handle(statement!))
    }

    private enum ThemeError: LocalizedError {
        case openFailed(String)
        case failedToPrepareStatement
        case executionFailed(String)
        case themeNotFound

        var errorDescription: String? {
            switch self {
            case .openFailed(let msg): return "Failed to open database: \(msg)"
            case .failedToPrepareStatement: return "Failed to prepare SQL statement"
            case .executionFailed(let msg): return "SQL execution failed: \(msg)"
            case .themeNotFound: return "Theme not found"
            }
        }
    }
}