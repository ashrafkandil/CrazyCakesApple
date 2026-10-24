import Foundation

struct GalleryCategory: Identifiable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let sort: Int
}

struct GalleryImage: Identifiable, Hashable {
    let id: Int
    let src: String
    let alt: String
    let width: Int?
    let height: Int?
    let sort: Int
    let featured: Bool
    let categorySlug: String
    let categoryTitle: String
}

struct GalleryVideo: Identifiable, Hashable {
    let id: Int
    let src: String
    let title: String
    let sort: Int
    let categorySlug: String
    let categoryTitle: String
}

struct Testimonial: Identifiable, Hashable {
    let id: Int
    let author: String
    let initials: String
    let date: String
    let quote: String
    let rating: Int
}

struct SocialLink: Identifiable, Hashable {
    let id: Int
    let label: String
    let href: String
    let icon: String
    let sort: Int
    let active: Bool
}

/// The in-memory cache of the whole SQLite content pack - the native twin of
/// ContentCache / readContentCache in src/db/database.ts.
struct ContentSnapshot {
    var content: [String: String] = [:]
    var categories: [GalleryCategory] = []
    var images: [GalleryImage] = []
    var videos: [GalleryVideo] = []
    var testimonials: [Testimonial] = []
    var eventTypes: [String] = []
    var socialLinks: [SocialLink] = []
    var version: String = "bundled"

    static let empty = ContentSnapshot()

    static let pageSize = 6

    func text(_ key: String) -> String {
        content[key] ?? "Missing content slot \"\(key)\""
    }

    /// Mirrors getGallery in src/db/database.ts, including the seeded shuffle.
    func gallery(category: String?, page: Int, shuffleSeed: String) -> GalleryPage {
        let active = (category?.isEmpty == false && category != "all") ? category : nil
        let filtered = active == nil ? images : images.filter { $0.categorySlug == active }
        let ordered = active == nil ? ContentSnapshot.shuffle(filtered, seed: shuffleSeed) : filtered
        let filteredVideos = active == nil ? videos : videos.filter { $0.categorySlug == active }
        let total = ordered.count
        let pageCount = max(1, Int(ceil(Double(total) / Double(ContentSnapshot.pageSize))))
        let safePage = min(max(page, 1), pageCount)
        let offset = (safePage - 1) * ContentSnapshot.pageSize
        let slice = offset < ordered.count
            ? Array(ordered[offset..<min(offset + ContentSnapshot.pageSize, ordered.count)])
            : []

        return GalleryPage(
            categories: categories,
            images: slice,
            videos: filteredVideos,
            activeCategory: active ?? "all",
            page: safePage,
            pageSize: ContentSnapshot.pageSize,
            total: total,
            pageCount: pageCount
        )
    }

    /// FNV-1a seed + mulberry32, identical to shuffleWithSeed in the React Native app,
    /// so the "All" gallery is stable for a given seed instead of re-shuffling per render.
    static func shuffle<T>(_ items: [T], seed: String) -> [T] {
        var state: UInt32 = 2166136261
        for scalar in seed.unicodeScalars {
            state = (state ^ UInt32(scalar.value)) &* 16777619
        }

        func random() -> Double {
            state = state &+ 0x6D2B79F5
            var value = state
            value = (value ^ (value >> 15)) &* (value | 1)
            value ^= value &+ ((value ^ (value >> 7)) &* (value | 61))
            return Double((value ^ (value >> 14))) / 4294967296.0
        }

        var shuffled = items
        guard shuffled.count > 1 else { return shuffled }
        for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let swapIndex = Int(random() * Double(index + 1))
            shuffled.swapAt(index, swapIndex)
        }
        return shuffled
    }

    /// Same shape as the Math.random() seeds used by GalleryScreen.
    static func makeShuffleSeed() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1000))-\(Double.random(in: 0..<1))"
    }
}

struct GalleryPage {
    let categories: [GalleryCategory]
    let images: [GalleryImage]
    let videos: [GalleryVideo]
    let activeCategory: String
    let page: Int
    let pageSize: Int
    let total: Int
    let pageCount: Int
}
