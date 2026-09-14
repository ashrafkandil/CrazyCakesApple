import SwiftUI
import UIKit

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
        case .about: return "About"
        case .gallery: return "Gallery"
        case .reviews: return "Reviews"
        case .pricing: return "Pricing"
        case .contact: return "Contact"
        }
    }

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
}

struct LocalImage: View {
    let src: String
    var contentDescription: String? = nil
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Palette.muted)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil else { return }
        let name = BundleResource.drawableName(forSrc: src)
        let ext = BundleResource.fileExtension(forSrc: src)
        if let url = BundleResource.url(named: name, ext: ext) {
            image = UIImage(contentsOfFile: url.path)
        }
    }
}

struct ScriptTitle: View {
    let text: String
    var size: CGFloat = 36
    var color: Color = Palette.primary
    var alignment: TextAlignment = .center

    var body: some View {
        Text(text)
            .font(AppFont.script(size))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment == .center ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.mutedForeground

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.serif(11))
            .tracking(2.9)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
}

struct SectionHeading: View {
    let title: String
    let eyebrow: String

    var body: some View {
        VStack(spacing: 10) {
            ScriptTitle(text: title, size: 38)
            Eyebrow(text: eyebrow)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SocialPill: View {
    let label: String
    let url: URL
    var onLight: Bool = true

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Text(label)
                    .font(AppFont.interMedium(13))
                    .foregroundStyle(onLight ? Palette.foreground : Palette.footerForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .overlay(
                Capsule()
                    .strokeBorder(
                        onLight ? Palette.border : Palette.footerForeground.opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct BrandFooterView: View {
    private let socials: [(String, String)] = [
        ("Instagram", "https://www.instagram.com/marwacrazycakes/"),
        ("TikTok", "https://www.tiktok.com/@marwacrazycakes"),
        ("X (Twitter)", "https://x.com/marwacrazycakes"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                LocalImage(src: "/assets/crazy/logo.png", contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Marwa Crazy Cakes")
                        .font(AppFont.script(28))
                        .foregroundStyle(Palette.footerForeground)
                    Text("EDIBLE ART. UNFORGETTABLE MOMENTS.")
                        .font(AppFont.serif(10))
                        .tracking(2)
                        .foregroundStyle(Palette.footerForeground.opacity(0.7))
                }
            }
            HStack(spacing: 10) {
                ForEach(socials, id: \.0) { name, urlString in
                    if let url = URL(string: urlString) {
                        SocialPill(label: name, url: url, onLight: false)
                    }
                }
            }
            Text("Chagrin Falls, Ohio")
                .font(AppFont.inter(13))
                .foregroundStyle(Palette.footerForeground.opacity(0.75))
            Text("© 2026 Marwa Crazy Cakes. All rights reserved.")
                .font(AppFont.inter(13))
                .foregroundStyle(Palette.footerForeground.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Palette.footer)
    }
}
