import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class AppDatabase {
    static let shared = AppDatabase()

    static let galleryPageSize = 6

    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "com.marwacrazycakes.app.database")

    private init() {}

    func bootstrap() {
        queue.sync { openIfNeeded() }
    }

    func content() -> [String: String] {
        query("SELECT key, value FROM content", params: []) { statement in
            (text(statement, 0), text(statement, 1))
        }.reduce(into: [String: String]()) { result, row in
            guard let key = row.0 else { return }
            result[key] = row.1 ?? ""
        }
    }

    func text(in content: [String: String], key: String) -> String {
        content[key] ?? "Missing content slot \(key)"
    }

    func testimonials() -> [Testimonial] {
        query(
            """
            SELECT id, author, initials, review_date, quote, rating
            FROM testimonials
            WHERE published = 1
            ORDER BY sort, id
            """,
            params: [],
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
        }.compactMap { $0 }
    }

    func eventTypes() -> [String] {
        query("SELECT label FROM event_types ORDER BY sort, id", params: []) { statement in
            text(statement, 0)
        }.compactMap { $0 }
    }

    func gallery(category: String?, page: Int) -> GalleryPage {
        let active = (category?.isEmpty == false && category != "all") ? category : nil
        let whereClause = active != nil ? "WHERE c.slug = ?" : ""
        let whereParams: [Any] = active != nil ? [active!] : []

        let categories = query(
            "SELECT id, slug, title, sort FROM categories ORDER BY sort",
            params: []
        ) { statement in
            guard let slug = text(statement, 1), let title = text(statement, 2) else { return nil }
            return GalleryCategory(
                id: Int(sqlite3_column_int64(statement, 0)),
                slug: slug,
                title: title,
                sort: Int(sqlite3_column_int(statement, 3))
            )
        }.compactMap { $0 }

        let total = query(
            "SELECT COUNT(*) FROM images i JOIN categories c ON c.id = i.category_id \(whereClause)",
            params: whereParams
        ) { statement in
            Int(sqlite3_column_int(statement, 0))
        }.first ?? 0

        let pageCount = max(1, (total + AppDatabase.galleryPageSize - 1) / AppDatabase.galleryPageSize)
        let safePage = min(max(page, 1), pageCount)
        let offset = (safePage - 1) * AppDatabase.galleryPageSize

        let images = query(
            """
            SELECT i.id, i.src, i.alt, i.width, i.height, i.sort, i.featured, c.slug, c.title
            FROM images i JOIN categories c ON c.id = i.category_id
            \(whereClause)
            ORDER BY i.sort, i.id
            LIMIT ? OFFSET ?
            """,
            params: whereParams + [AppDatabase.galleryPageSize, offset]
        ) { statement -> GalleryImage? in
            guard let src = text(statement, 1), let alt = text(statement, 2),
                  let slug = text(statement, 7), let title = text(statement, 8) else { return nil }
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
        }.compactMap { $0 }

        return GalleryPage(
            categories: categories,
            images: images,
            activeCategory: active ?? "all",
            page: safePage,
            pageSize: AppDatabase.galleryPageSize,
            total: total,
            pageCount: pageCount
        )
    }

    private func openIfNeeded() {
        guard handle == nil else { return }
        guard let bundledURL = BundleResource.url(named: "crazy-cakes", ext: "db") else { return }
        let fileManager = FileManager.default
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let databaseDirectory = supportDirectory?.appendingPathComponent("Database", isDirectory: true)
        try? fileManager.createDirectory(at: databaseDirectory ?? URL(fileURLWithPath: "/tmp"), withIntermediateDirectories: true)
        let writableURL = (databaseDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("crazy-cakes.db")

        if !fileManager.fileExists(atPath: writableURL.path) {
            try? fileManager.removeItem(at: writableURL)
            try? fileManager.copyItem(at: bundledURL, to: writableURL)
        }

        sqlite3_open_v2(writableURL.path, &handle, SQLITE_OPEN_READONLY, nil)
    }

    private func query<T>(_ sql: String, params: [Any], map: @escaping (OpaquePointer?) -> T?) -> [T] {
        queue.sync {
            bootstrapLocked()
            guard let handle else { return [] }
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
    }

    private func bootstrapLocked() {
        if handle == nil {
            openIfNeededLocked()
        }
    }

    private func openIfNeededLocked() {
        guard handle == nil else { return }
        guard let bundledURL = BundleResource.url(named: "crazy-cakes", ext: "db") else { return }
        let fileManager = FileManager.default
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let databaseDirectory = supportDirectory?.appendingPathComponent("Database", isDirectory: true)
        try? fileManager.createDirectory(at: databaseDirectory ?? URL(fileURLWithPath: "/tmp"), withIntermediateDirectories: true)
        let writableURL = (databaseDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("crazy-cakes.db")
        if !fileManager.fileExists(atPath: writableURL.path) {
            try? fileManager.copyItem(at: bundledURL, to: writableURL)
        }
        sqlite3_open_v2(writableURL.path, &handle, SQLITE_OPEN_READONLY, nil)
    }

    private func bind(_ params: [Any], to statement: OpaquePointer?) {
        for (index, param) in params.enumerated() {
            let position = Int32(index + 1)
            switch param {
            case let value as Int:
                sqlite3_bind_int64(statement, position, Int64(value))
            case let value as String:
                sqlite3_bind_text(statement, position, value, -1, sqliteTransient)
            default:
                sqlite3_bind_null(statement, position)
            }
        }
    }

    private func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: cString)
    }
}
