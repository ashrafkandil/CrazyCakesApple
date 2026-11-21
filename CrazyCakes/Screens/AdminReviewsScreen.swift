import SwiftUI
import Foundation

struct AdminReviewsScreen: View {
    @State private var password = ""
    @State private var authenticated = false
    @State private var pendingReviews: [Testimonial] = []
    @State private var loading = false
    @State private var error: String?

    private let adminPassword = "crazycakes13"

    var body: some View {
        NavigationStack {
            if !authenticated {
                VStack(spacing: 24) {
                    Text("Review Moderation")
                        .font(AppFont.script(28))
                        .foregroundStyle(Palette.primary)

                    if let error = error {
                        Text(error)
                            .font(AppFont.inter(14))
                            .foregroundStyle(.red)
                    }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.inter(14))
                        .frame(maxWidth: 320)

                    Button("Access Reviews") {
                        if password == adminPassword {
                            authenticated = true
                            loadPendingReviews()
                        } else {
                            error = "Incorrect password"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.primary)
                }
                .padding()
            } else {
                List {
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if pendingReviews.isEmpty {
                        Text("No pending reviews to moderate.")
                            .font(AppFont.inter(16))
                            .foregroundStyle(Palette.mutedForeground)
                    } else {
                        ForEach(pendingReviews) { review in
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    Text(review.initials)
                                        .font(AppFont.interSemiBold(15))
                                        .foregroundStyle(Palette.primaryForeground)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Palette.primary))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(review.author)
                                            .font(AppFont.interSemiBold(14))
                                            .foregroundStyle(Palette.primary)
                                        Text(review.date)
                                            .font(AppFont.inter(11))
                                            .foregroundStyle(Palette.mutedForeground)
                                    }

                                    Spacer()

                                    Text(String(repeating: "★", count: max(0, review.rating)))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Palette.gold)
                                }

                                Text("“\(review.quote)”")
                                    .font(AppFont.inter(13))
                                    .lineSpacing(10)
                                    .italic()
                                    .foregroundStyle(Palette.mutedForeground)

                                HStack(spacing: 12) {
                                    Button("Approve") {
                                        approveReview(review.id)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Palette.primary)

                                    Button("Delete") {
                                        deleteReview(review.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                }
                .navigationTitle("Pending Reviews")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Logout") {
                            authenticated = false
                        }
                    }
                }
            }
        }
    }

    func loadPendingReviews() {
        loading = true
        error = nil

        Task {
            do {
                let db = try await openDatabase()
                let reviews = try await fetchPendingReviews(from: db)
                await MainActor.run {
                    self.pendingReviews = reviews
                    self.loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load pending reviews: \(error.localizedDescription)"
                    self.loading = false
                }
            }
        }
    }

    func approveReview(_ id: Int) {
        Task {
            let result = await ApiClient.shared.approveReview(id: id)
            await MainActor.run {
                if result.isSuccess {
                    self.pendingReviews.removeAll { $0.id == id }
                    print("Review approved successfully")
                } else {
                    self.error = result.errorMessage ?? "Failed to approve review"
                    print("Failed to approve review: \(result.errorMessage ?? "Unknown error")")
                }
            }
        }
    }

    func deleteReview(_ id: Int) {
        Task {
            let result = await ApiClient.shared.deleteReview(id: id)
            await MainActor.run {
                if result.isSuccess {
                    self.pendingReviews.removeAll { $0.id == id }
                    print("Review deleted successfully")
                } else {
                    self.error = result.errorMessage ?? "Failed to delete review"
                    print("Failed to delete review: \(result.errorMessage ?? "Unknown error")")
                }
            }
        }
    }

    private func openDatabase() async throws -> OpaquePointer {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbURL = appSupport.appendingPathComponent("Database/crazy-cakes.db")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var handle: OpaquePointer?
                let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
                let result = sqlite3_open_v2(dbURL.path, &handle, flags, nil)
                if result == SQLITE_OK, let handle = handle {
                    sqlite3_busy_timeout(handle, 5000)
                    continuation.resume(returning: handle)
                } else {
                    let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
                    if let handle { sqlite3_close(handle) }
                    continuation.resume(throwing: NSError(domain: "SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }
        }
    }

    private func fetchPendingReviews(from db: OpaquePointer) async throws -> [Testimonial] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var reviews: [Testimonial] = []
                var statement: OpaquePointer?
                let sql = "SELECT id, author, initials, review_date, quote, rating FROM testimonials WHERE published = 0 ORDER BY id"

                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                    continuation.resume(throwing: NSError(domain: "SQLite", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement"]))
                    return
                }
                defer { sqlite3_finalize(statement) }

                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int64(statement, 0))
                    let author = String(cString: sqlite3_column_text(statement, 1))
                    let initials = String(cString: sqlite3_column_text(statement, 2))
                    let date = String(cString: sqlite3_column_text(statement, 3))
                    let quote = String(cString: sqlite3_column_text(statement, 4))
                    let rating = Int(sqlite3_column_int(statement, 5))

                    reviews.append(Testimonial(
                        id: id,
                        author: author,
                        initials: initials,
                        date: date,
                        quote: quote,
                        rating: rating
                    ))
                }

                continuation.resume(returning: reviews)
            }
        }
    }

    private func executeSQL(_ db: OpaquePointer, _ sql: String, _ params: [Any]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var statement: OpaquePointer?
                let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
                guard result == SQLITE_OK else {
                    continuation.resume(throwing: NSError(domain: "SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Failed to prepare: \(sql)"]))
                    return
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

                if sqlite3_step(statement) == SQLITE_DONE {
                    continuation.resume(returning: ())
                } else {
                    let message = String(cString: sqlite3_errmsg(db))
                    continuation.resume(throwing: NSError(domain: "SQLite", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }
        }
    }
}