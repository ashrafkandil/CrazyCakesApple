import CryptoKit
import Foundation

enum ContentUpdateError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case invalidManifest(String)
    case sizeMismatch(expected: Int, received: Int)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The mobile content URL is not valid."
        case .badStatus(let status):
            return "The content host answered with HTTP \(status)."
        case .invalidManifest(let detail):
            return "The mobile content manifest is invalid: \(detail)"
        case .sizeMismatch(let expected, let received):
            return "Downloaded content database size mismatch (expected \(expected), received \(received))."
        case .checksumMismatch:
            return "Downloaded content database failed SHA-256 verification."
        }
    }
}

/// Downloads and verifies the published mobile content pack - the native twin of
/// downloadContentUpdate / parseManifest in src/db/database.ts.
actor ContentUpdater {
    static let shared = ContentUpdater()

    struct Manifest {
        let version: String
        let file: String
        let bytes: Int
        let sha256: String
    }

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private var running = false

    /// Checks the host and installs a newer pack. Returns true when the active
    /// database was replaced. Never throws: failures keep the last valid database.
    func check(database: AppDatabase) async -> Bool {
        guard !running else { return false }
        running = true
        defer { running = false }

        let base = AppConfig.contentBaseURL
        guard !base.isEmpty else { return false }

        do {
            let manifest = try await fetchManifest(base: base)
            if database.version() == manifest.version { return false }
            try await install(manifest: manifest, base: base, database: database)
            return true
        } catch {
            print("Unable to refresh mobile content; keeping the last valid local database.", error)
            return false
        }
    }

    private func fetchManifest(base: String) async throws -> Manifest {
        guard let url = URL(string: base + "/manifest.json") else { throw ContentUpdateError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ContentUpdateError.badStatus(http.statusCode)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ContentUpdateError.invalidManifest("the document is not a JSON object")
        }
        guard let version = object["version"] as? String, AppDatabase.isVersion(version) else {
            throw ContentUpdateError.invalidManifest("invalid version")
        }
        guard let database = object["database"] as? [String: Any] else {
            throw ContentUpdateError.invalidManifest("missing database descriptor")
        }
        guard let file = database["file"] as? String, file == AppDatabase.databaseName else {
            throw ContentUpdateError.invalidManifest("invalid database file name")
        }
        guard let bytes = database["bytes"] as? NSNumber, bytes.intValue > 0 else {
            throw ContentUpdateError.invalidManifest("invalid database size")
        }
        guard let sha256 = database["sha256"] as? String, AppDatabase.isVersion(sha256) else {
            throw ContentUpdateError.invalidManifest("invalid database checksum")
        }
        return Manifest(version: version, file: file, bytes: bytes.intValue, sha256: sha256)
    }

    private func install(manifest: Manifest, base: String, database: AppDatabase) async throws {
        guard var components = URLComponents(string: base + "/" + manifest.file) else {
            throw ContentUpdateError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "version", value: manifest.version)]
        guard let url = components.url else { throw ContentUpdateError.invalidURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ContentUpdateError.badStatus(http.statusCode)
        }
        guard data.count == manifest.bytes else {
            throw ContentUpdateError.sizeMismatch(expected: manifest.bytes, received: data.count)
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.sha256 else { throw ContentUpdateError.checksumMismatch }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mobile-content-downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent("\(manifest.version).db")
        try? FileManager.default.removeItem(at: temporary)
        try data.write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }

        try AppDatabase.validateDatabase(at: temporary)
        try database.adoptDownloadedDatabase(at: temporary, version: manifest.version)
    }
}
