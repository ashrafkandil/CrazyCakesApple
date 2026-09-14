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

struct GalleryPage {
    let categories: [GalleryCategory]
    let images: [GalleryImage]
    let activeCategory: String
    let page: Int
    let pageSize: Int
    let total: Int
    let pageCount: Int
}

struct Testimonial: Identifiable, Hashable {
    let id: Int
    let author: String
    let initials: String
    let date: String
    let quote: String
    let rating: Int
}
