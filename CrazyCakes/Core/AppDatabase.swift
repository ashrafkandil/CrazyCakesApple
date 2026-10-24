import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case missingBundledDatabase
    case openFailed(String)
    case integrityCheckFailed(String)
    case missingTable(String)
    case emptyCategories
    case invalidVersion

    var errorDescription: String? {
        switch self {
        case .missingBundledDatabase:
            return "The bundled content database is missing from the app."
        case .openFailed(let detail):
            return "Could not open the content database: \(detail)"
        case .integrityCheckFailed(let detail):
            return "SQLite integrity check failed: \(detail)."
        case .missingTable(let table):
            return "The content database is missing the \(table) table."
        case .emptyCategories:
            return "The content database contains no categories."
        case .invalidVersion:
            return "The saved content version does not match the downloaded database."
        }
    }
}

/// SQLite repository and content-pack store - the native twin of src/db/database.ts.
///
/// The app ships a read-only copy of the mobile content database, copies it into
/// Application Support on first launch, and swaps in a validated downloaded copy when
/// a newer mobile content pack is published at AppConfig.contentBaseURL.
final class AppDatabase {
    static let shared = AppDatabase()

    static let galleryPageSize = 6
    static let databaseName = "crazy-cakes.db"
    static let contentVersionKey = "content_version"
    static let requiredTables = [
        "categories",
        "images",
        "videos",
        "testimonials",
        "content",
        "event_types",
        "social_links",
    ]

    private let queue = DispatchQueue(label: "com.marwacrazycakes.app.database")
    private var bundledHandle: OpaquePointer?
    private var activeHandle: OpaquePointer?
    private var activeIsBundled = true
    private var storeVersion = "bundled"

    private init() {}

    // MARK: - Locations

    /// Application Support/Database, where the writable copies live.
    var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Database", isDirectory: true)
    }

    private var bundledCopyURL: URL {
        directory.appendingPathComponent(AppDatabase.databaseName)
    }

    func cachedDatabaseURL(version: String) -> URL {
        directory.appendingPathComponent("mobile-content-\(version).db")
    }

    // MARK: - Bootstrap

    /// Copies the bundled database into Application Support the first time the app runs.
    func installBundledDatabaseIfNeeded() throws {
        try queue.sync {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = bundledCopyURL
            if fileManager.fileExists(atPath: target.path) { return }

            guard let bundledURL = BundleResource.url(named: "crazy-cakes", ext: "db") else {
                throw DatabaseError.missingBundledDatabase
            }
            let temporary = directory.appendingPathComponent("\(AppDatabase.databaseName).installing")
            try? fileManager.removeItem(at: temporary)
            do {
                try fileManager.copyItem(at: bundledURL, to: temporary)
                try AppDatabase.validateDatabase(at: temporary)
                try? fileManager.removeItem(at: target)
                try fileManager.moveItem(at: temporary, to: target)
            } catch {
                try? fileManager.removeItem(at: temporary)
                throw error
            }
        }
    }

    /// Opens the bundled database and restores the last validated downloaded pack, if any.
    func openActive() throws {
        try queue.sync { try openActiveLocked() }
    }

    /// The active content version ("bundled" or the downloaded pack version).
    func version() -> String {
        queue.sync { storeVersion }
    }

    private func openActiveLocked() throws {
        if bundledHandle == nil { try openBundledLocked() }
        guard let bundled = bundledHandle else { throw DatabaseError.missingBundledDatabase }
        try AppDatabase.createMetaTable(bundled)

        let installed = try AppDatabase.metaValue(bundled, key: AppDatabase.contentVersionKey)
        var targetHandle = bundled
        var targetIsBundled = true
        var version = "bundled"

        if let installed {
            if AppDatabase.isVersion(installed) {
                let cachedURL = cachedDatabaseURL(version: installed)
                if FileManager.default.fileExists(atPath: cachedURL.path) {
                    do {
                        let handle = try AppDatabase.open(url: cachedURL)
                        do {
                            try AppDatabase.validate(handle)
                            let cachedVersion = try AppDatabase.metaValue(handle, key: AppDatabase.contentVersionKey)
                            guard cachedVersion == installed else { throw DatabaseError.invalidVersion }
                        } catch {
                            sqlite3_close(handle)
                            throw error
                        }
                        targetHandle = handle
                        targetIsBundled = false
                        version = installed
                    } catch {
                        try? FileManager.default.removeItem(at: cachedURL)
                        try? AppDatabase.deleteMetaValue(bundled, key: AppDatabase.contentVersionKey)
                        print("Could not restore the last downloaded content; using the bundled database.", error)
                    }
                } else {
                    try? AppDatabase.deleteMetaValue(bundled, key: AppDatabase.contentVersionKey)
                    print("Saved mobile content database is missing; using the bundled database.")
                }
            } else {
                try? AppDatabase.deleteMetaValue(bundled, key: AppDatabase.contentVersionKey)
                print("Discarded an invalid saved mobile content version.")
            }
        }

        if let activeHandle, !activeIsBundled {
            sqlite3_close(activeHandle)
        }
        activeHandle = targetHandle
        activeIsBundled = targetIsBundled
        storeVersion = version
    }

    private func openBundledLocked() throws {
        guard bundledHandle == nil else { return }
        let url = bundledCopyURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw DatabaseError.missingBundledDatabase }
        bundledHandle = try AppDatabase.open(url: url)
    }

    // MARK: - Reading

    /// Reads the whole content cache from the active database, exactly like readContentCache.
    func snapshot() -> ContentSnapshot {
        queue.sync {
            if activeHandle == nil {
                try? openActiveLocked()
            }
            guard let activeHandle else { return .empty }
            return AppDatabase.loadSnapshot(from: activeHandle, version: storeVersion)
        }
    }

    // MARK: - Content pack updates

    /// Installs a validated, downloaded database and makes it the active content source.
    func adoptDownloadedDatabase(at sourceURL: URL, version: String) throws {
        try queue.sync {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = cachedDatabaseURL(version: version)
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: sourceURL, to: destination)

            let handle = try AppDatabase.open(url: destination)
            do {
                try AppDatabase.validate(handle)
                try AppDatabase.createMetaTable(handle)
                try AppDatabase.setMetaValue(handle, key: AppDatabase.contentVersionKey, value: version)
            } catch {
                sqlite3_close(handle)
                try? fileManager.removeItem(at: destination)
                throw error
            }

            if bundledHandle == nil { try openBundledLocked() }
            if let bundledHandle {
                try AppDatabase.createMetaTable(bundledHandle)
                try AppDatabase.setMetaValue(bundledHandle, key: AppDatabase.contentVersionKey, value: version)
            }

            if let activeHandle, !activeIsBundled {
                sqlite3_close(activeHandle)
            }
            activeHandle = handle
            activeIsBundled = false
            storeVersion = version
            pruneCachedDatabases(keeping: version)
        }
    }

    private func pruneCachedDatabases(keeping version: String) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        let current = cachedDatabaseURL(version: version).lastPathComponent
        for url in contents where url.lastPathComponent.hasPrefix("mobile-content-")
            && url.lastPathComponent.hasSuffix(".db")
            && url.lastPathComponent != current {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Validation

    static func isVersion(_ value: String) -> Bool {
        value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
    }

    static func validateDatabase(at url: URL) throws {
        let handle = try open(url: url)
        defer { sqlite3_close(handle) }
        try validate(handle)
    }

    static func validate(_ handle: OpaquePointer) throws {
        let integrity = query(handle, sql: "PRAGMA integrity_check", params: []) { statement -> String? in
            text(statement, 0)
        }.first
        guard integrity == "ok" else {
            throw DatabaseError.integrityCheckFailed(integrity ?? "no result")
        }
        for table in requiredTables {
            var statement: OpaquePointer?
            let result = sqlite3_prepare_v2(handle, "SELECT 1 FROM \(table) LIMIT 0", -1, &statement, nil)
            sqlite3_finalize(statement)
            guard result == SQLITE_OK else { throw DatabaseError.missingTable(table) }
        }
        let categories = query(handle, sql: "SELECT count(*) FROM categories", params: []) { statement -> Int in
            Int(sqlite3_column_int(statement, 0))
        }.first ?? 0
        guard categories > 0 else { throw DatabaseError.emptyCategories }
    }

    // MARK: - SQLite plumbing

    static func open(url: URL) throws -> OpaquePointer {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.openFailed(message)
        }
        sqlite3_busy_timeout(handle, 5000)
        return handle
    }

    static func createMetaTable(_ handle: OpaquePointer) throws {
        try execute(handle, sql: """
            CREATE TABLE IF NOT EXISTS mobile_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
            """, params: [])
    }

    static func metaValue(_ handle: OpaquePointer, key: String) throws -> String? {
        query(handle, sql: "SELECT value FROM mobile_meta WHERE key = ?", params: [key]) { statement in
            text(statement, 0)
        }.first
    }

    static func setMetaValue(_ handle: OpaquePointer, key: String, value: String) throws {
        try execute(
            handle,
            sql: "INSERT INTO mobile_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params: [key, value]
        )
    }

    static func deleteMetaValue(_ handle: OpaquePointer, key: String) throws {
        try execute(handle, sql: "DELETE FROM mobile_meta WHERE key = ?", params: [key])
    }

    static func execute(_ handle: OpaquePointer, sql: String, params: [Any]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    static func query<T>(
        _ handle: OpaquePointer,
        sql: String,
        params: [Any],
        map: (OpaquePointer?) -> T?
    ) -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)
        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = map(statement) {
                results.append(value)
            }
        }
        return results
    }

    static func bind(_ params: [Any], to statement: OpaquePointer?) {
        for (index, param) in params.enumerated() {
            let position = Int32(index + 1)
            switch param {
            case let value as Int:
                sqlite3_bind_int64(statement, position, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, position, value)
            case let value as String:
                sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
            case let value as Bool:
                sqlite3_bind_int(statement, position, value ? 1 : 0)
            default:
                sqlite3_bind_null(statement, position)
            }
        }
    }

    static func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: cString)
    }

    // MARK: - Cache loading

    static func loadSnapshot(from handle: OpaquePointer, version: String) -> ContentSnapshot {
        var snapshot = ContentSnapshot()
        snapshot.version = version

        snapshot.categories = query(
            handle,
            sql: "SELECT id, slug, title, sort FROM categories ORDER BY sort",
            params: []
        ) { statement in
            guard let slug = text(statement, 1), let title = text(statement, 2) else { return nil }
            return GalleryCategory(
                id: Int(sqlite3_column_int64(statement, 0)),
                slug: slug,
                title: title,
                sort: Int(sqlite3_column_int(statement, 3))
            )
        }

        snapshot.images = query(
            handle,
            sql: """
                SELECT i.id, i.src, i.alt, i.width, i.height, i.sort, i.featured, i.category_id,
                       c.slug, c.title AS categoryTitle
                FROM images i JOIN categories c ON c.id = i.category_id
                ORDER BY i.sort, i.id
                """,
            params: []
        ) { statement in
            guard let src = text(statement, 1), let alt = text(statement, 2),
                  let slug = text(statement, 8), let title = text(statement, 9) else { return nil }
            return GalleryImage(
                id: Int(sqlite3_column_int64(statement, 0)),
                src: src,
                alt: alt,
                width: sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 3)),
                height: sqlite3_column_type(statement, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 4)),
                sort: Int(sqlite3_column_int(statement, 5)),
                featured: sqlite3_column_int(statement, 6) == 1,
                categorySlug: slug,
                categoryTitle: title
            )
        }

        snapshot.videos = query(
            handle,
            sql: """
                SELECT v.id, v.src, v.title, v.sort, v.category_id, c.slug, c.title AS categoryTitle
                FROM videos v JOIN categories c ON c.id = v.category_id
                ORDER BY v.sort, v.id
                """,
            params: []
        ) { statement in
            guard let src = text(statement, 1), let title = text(statement, 2),
                  let slug = text(statement, 5), let categoryTitle = text(statement, 6) else { return nil }
            return GalleryVideo(
                id: Int(sqlite3_column_int64(statement, 0)),
                src: src,
                title: title,
                sort: Int(sqlite3_column_int(statement, 3)),
                categorySlug: slug,
                categoryTitle: categoryTitle
            )
        }

        snapshot.testimonials = query(
            handle,
            sql: """
                SELECT id, author, initials, review_date AS date, quote, rating
                FROM testimonials WHERE published = 1 ORDER BY sort, id
                """,
            params: []
        ) { statement in
            guard let author = text(statement, 1), let initials = text(statement, 2),
                  let date = text(statement, 3), let quote = text(statement, 4) else { return nil }
            return Testimonial(
                id: Int(sqlite3_column_int64(statement, 0)),
                author: author,
                initials: initials,
                date: date,
                quote: quote,
                rating: Int(sqlite3_column_int(statement, 5))
            )
        }

        let rows = query(
            handle,
            sql: "SELECT key, value FROM content",
            params: []
        ) { statement -> (String, String)? in
            guard let key = text(statement, 0) else { return nil }
            return (key, text(statement, 1) ?? "")
        }
        snapshot.content = Dictionary(uniqueKeysWithValues: rows)

        snapshot.eventTypes = query(
            handle,
            sql: "SELECT label FROM event_types ORDER BY sort, id",
            params: []
        ) { statement in
            text(statement, 0)
        }

        snapshot.socialLinks = query(
            handle,
            sql: "SELECT id, label, href, icon, sort, active FROM social_links WHERE active = 1 ORDER BY sort, id",
            params: []
        ) { statement in
            guard let label = text(statement, 1), let href = text(statement, 2), let icon = text(statement, 3) else {
                return nil
            }
            return SocialLink(
                id: Int(sqlite3_column_int64(statement, 0)),
                label: label,
                href: href,
                icon: icon,
                sort: Int(sqlite3_column_int(statement, 4)),
                active: sqlite3_column_int(statement, 5) == 1
            )
        }

        return snapshot
    }
}
