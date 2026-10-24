import Foundation

/// The six app screens - the native twin of src/navigation/destinations.ts.
enum Destination: Int, CaseIterable, Identifiable {
    case home
    case about
    case gallery
    case reviews
    case pricing
    case contact

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .about: return "About Us"
        case .gallery: return "Gallery"
        case .reviews: return "Reviews"
        case .pricing: return "Pricing"
        case .contact: return "Contact"
        }
    }

    /// SF Symbols standing in for the Ionicons used by the React Native tab bar.
    var symbol: String {
        switch self {
        case .home: return "house"
        case .about: return "person.crop.circle"
        case .gallery: return "photo.on.rectangle"
        case .reviews: return "star"
        case .pricing: return "tag"
        case .contact: return "envelope"
        }
    }

    var assistantPage: AssistantPage {
        switch self {
        case .home: return .home
        case .about: return .about
        case .gallery: return .gallery
        case .reviews: return .reviews
        case .pricing: return .pricing
        case .contact: return .contact
        }
    }
}
