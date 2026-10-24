import Foundation
import ImageIO
import UIKit

/// Resolves database media paths to bundled files or to the published content pack,
/// with a memory cache - the native twin of expo-image plus components/media.ts.
final class MediaLibrary {
    static let shared = MediaLibrary()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var contentVersion = "bundled"
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "mobile-content-media"
        )
        session = URLSession(configuration: configuration)
        cache.countLimit = 240
    }

    func setVersion(_ version: String) {
        lock.lock()
        contentVersion = version
        lock.unlock()
    }

    func version() -> String {
        lock.lock()
        defer { lock.unlock() }
        return contentVersion
    }

    /// contentMediaUrl in src/components/media.ts: only cake media is published, and
    /// the active content version busts the cache after a pack update.
    func remoteURL(for src: String) -> URL? {
        let base = AppConfig.contentBaseURL
        guard !base.isEmpty else { return nil }
        let path = MediaRegistry.normalizedPath(src)
        guard path.hasPrefix("/assets/crazy/") || path.hasPrefix("/assets/videos/") else { return nil }
        guard var components = URLComponents(string: base) else { return nil }
        components.path = components.path + "/media" + path
        components.queryItems = [URLQueryItem(name: "v", value: version())]
        return components.url
    }

    /// Synchronous bundled lookup, used for logos and placeholders.
    func bundledImage(for src: String) -> UIImage? {
        guard let file = MediaRegistry.imageFile(for: src),
              let url = BundleResource.url(forMediaFile: file) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func bundledVideoURL(for src: String) -> URL? {
        guard let file = MediaRegistry.videoFile(for: src) else { return nil }
        return BundleResource.url(forMediaFile: file)
    }

    func cachedImage(for src: String) -> UIImage? {
        cache.object(forKey: cacheKey(for: src) as NSString)
    }

    /// Remote first, bundled fallback - the same order as LocalImage in components/ui.tsx.
    func image(for src: String) async -> UIImage? {
        let key = cacheKey(for: src)
        if let cached = cache.object(forKey: key as NSString) { return cached }

        if let remote = remoteURL(for: src) {
            var request = URLRequest(url: remote, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let image = MediaLibrary.decode(data: data) {
                cache.setObject(image, forKey: key as NSString)
                return image
            }
        }

        guard let file = MediaRegistry.imageFile(for: src),
              let url = BundleResource.url(forMediaFile: file),
              let data = try? Data(contentsOf: url),
              let image = MediaLibrary.decode(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    private func cacheKey(for src: String) -> String {
        "\(version())|\(MediaRegistry.normalizedPath(src))"
    }

    /// Down-samples large photographs so grids of 4000px originals stay in memory budget.
    private static func decode(data: Data, maxPixel: Int = 2048) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
