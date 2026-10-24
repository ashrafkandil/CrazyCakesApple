import SwiftUI
import UIKit

/// Bundled-or-remote image - the native twin of LocalImage in src/components/ui.tsx.
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
                Palette.muted
            }
        }
        .clipped()
        .task(id: "\(src)#\(MediaLibrary.shared.version())") {
            await load()
        }
        .accessibilityLabel(contentDescription ?? "")
        .accessibilityHidden(contentDescription == nil)
    }

    private func load() async {
        if let cached = MediaLibrary.shared.cachedImage(for: src) {
            image = cached
            return
        }
        let loaded = await MediaLibrary.shared.image(for: src)
        guard !Task.isCancelled else { return }
        image = loaded
    }
}

/// A fixed aspect-ratio media box that crops like the React Native Image component.
struct AspectImage: View {
    let src: String
    var aspect: CGFloat = 16.0 / 9.0
    var contentMode: ContentMode = .fill
    var contentDescription: String? = nil

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay(
                LocalImage(src: src, contentDescription: contentDescription, contentMode: contentMode)
            )
            .clipped()
    }
}

/// The repeating translucent logo backdrop used behind every screen
/// (WatermarkPattern in src/components/ui.tsx).
struct WatermarkPattern: View {
    var tileSize: CGFloat = 88
    var opacity: Double = 0.055

    var body: some View {
        Group {
            if let tile = WatermarkTile.image(tileSize: tileSize) {
                Image(uiImage: tile)
                    .resizable(resizingMode: .tile)
                    .opacity(opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum WatermarkTile {
    private static var cache: [Int: UIImage] = [:]
    private static let lock = NSLock()

    static func image(tileSize: CGFloat) -> UIImage? {
        guard tileSize > 0 else { return nil }
        let key = Int(tileSize.rounded())
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        guard let logo = MediaLibrary.shared.bundledImage(for: "/assets/crazy/logo.png") else { return nil }

        let size = CGSize(width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let tile = renderer.image { _ in
            let scale = min(size.width / logo.size.width, size.height / logo.size.height)
            let drawSize = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
            logo.draw(in: CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        cache[key] = tile
        return tile
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
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.mutedForeground
    var alignment: TextAlignment = .center

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.serif(11))
            .tracking(Metrics.eyebrowLetterSpacing)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
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
        .padding(.horizontal, 20)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct PrimaryButton: View {
    let label: String
    var outline: Bool = false
    var wide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.interMedium(15))
                .foregroundStyle(outline ? Palette.primary : Palette.primaryForeground)
                .padding(.vertical, 12)
                .padding(.horizontal, 22)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(Capsule().fill(outline ? Color.clear : Palette.primary))
                .overlay(
                    Capsule().strokeBorder(
                        outline ? Palette.primary : Color.clear,
                        lineWidth: outline ? 1 : 0
                    )
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct SocialPill: View {
    let label: String
    let url: String
    var dark: Bool = false

    var body: some View {
        if let link = URL(string: url) {
            Link(destination: link) {
                Text(label)
                    .font(AppFont.interMedium(13))
                    .foregroundStyle(dark ? Palette.footerForeground : Palette.foreground)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .overlay(
                        Capsule().strokeBorder(
                            dark ? Palette.footerForeground.opacity(0.35) : Palette.border,
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
        } else {
            Text(label)
                .font(AppFont.interMedium(13))
                .foregroundStyle(dark ? Palette.footerForeground : Palette.foreground)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
        }
    }
}

struct BrandFooter: View {
    let snapshot: ContentSnapshot

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white)
                    LocalImage(src: "/assets/crazy/logo.png", contentMode: .fit)
                        .frame(width: 56, height: 56)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Marwa Crazy Cakes")
                        .font(AppFont.script(28))
                        .foregroundStyle(Palette.footerForeground)
                    Text("Edible art. Unforgettable moments.")
                        .font(AppFont.serif(10))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.footerAlpha(0.7))
                }
            }

            HStack(spacing: 10) {
                ForEach(snapshot.socialLinks) { social in
                    SocialPill(label: social.label, url: social.href, dark: true)
                }
            }

            Text("© 2026 Marwa Crazy Cakes. All rights reserved.")
                .font(AppFont.inter(13))
                .foregroundStyle(Palette.footerAlpha(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Palette.footer)
    }
}

extension View {
    /// platformShadow in src/components/ui.tsx (iOS branch).
    func cardShadow() -> some View {
        shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
