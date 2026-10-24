import Combine
import SwiftUI

struct HomeScreen: View {
    let snapshot: ContentSnapshot
    let onNavigate: (Destination) -> Void

    private struct HeroSlide {
        let src: String
        let alt: String
    }

    private struct DestinationCard {
        let screen: Destination
        let image: String
        let keyId: String
    }

    private static let heroSlides = [
        HeroSlide(src: "/assets/crazy/hero-1.jpg", alt: "Jaw-dropping sculpted cake masterpiece"),
        HeroSlide(src: "/assets/crazy/hero-2.jpg", alt: "Sophisticated multi-tiered wedding cake with edible flowers"),
        HeroSlide(src: "/assets/crazy/hero-3.jpg", alt: "Whimsical sculpted cake with playful design"),
        HeroSlide(src: "/assets/crazy/hero-4.jpg", alt: "Fine edible detailing with sugar flowers and gold leaf"),
    ]

    private static let cards = [
        DestinationCard(screen: .about, image: "/assets/crazy/Marwa.png", keyId: "about"),
        DestinationCard(screen: .gallery, image: "/assets/crazy/celebration-1.JPEG", keyId: "gallery"),
        DestinationCard(screen: .reviews, image: "/assets/crazy/Testimony.png", keyId: "reviews"),
        DestinationCard(screen: .pricing, image: "/assets/crazy/pricing.jpeg", keyId: "pricing"),
    ]

    @State private var heroIndex = 0
    private let timer = Timer.publish(every: 6.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            ScrollView {
                VStack(spacing: 0) {
                    hero(width: proxy.size.width, height: heroHeight(proxy.size))
                    heroCopy(isWide: isWide)
                    teasers(isWide: isWide)
                    BrandFooter(snapshot: snapshot)
                }
            }
        }
    }

    /// The same responsive height formula as HomeScreen.tsx.
    private func heroHeight(_ size: CGSize) -> CGFloat {
        let isPortrait = size.height >= size.width
        let primary = isPortrait ? size.width * 0.9 : size.height * 0.86
        let secondary = isPortrait ? size.height * 0.56 : size.width * 0.45
        return min(min(primary, secondary), 560)
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        TabView(selection: $heroIndex) {
            ForEach(0..<Self.heroSlides.count, id: \.self) { index in
                LocalImage(
                    src: Self.heroSlides[index].src,
                    contentDescription: Self.heroSlides[index].alt,
                    contentMode: .fit
                )
                .frame(width: width, height: height)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: width, height: height)
        .onReceive(timer) { _ in
            let next = (heroIndex + 1) % Self.heroSlides.count
            withAnimation { heroIndex = next }
        }
    }

    private func heroCopy(isWide: Bool) -> some View {
        VStack(spacing: 8) {
            Text(snapshot.text("home.hero.title"))
                .font(AppFont.script(isWide ? 52 : 38))
                .foregroundStyle(Palette.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Eyebrow(text: snapshot.text("home.hero.tagline"))

            Text(snapshot.text("home.hero.body"))
                .font(AppFont.inter(15))
                .lineSpacing(6)
                .foregroundStyle(Palette.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                PrimaryButton(label: snapshot.text("home.hero.cta.gallery")) {
                    onNavigate(.gallery)
                }
                PrimaryButton(label: snapshot.text("home.hero.cta.contact")) {
                    onNavigate(.contact)
                }
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .background(Palette.background)
    }

    private func teasers(isWide: Bool) -> some View {
        VStack(spacing: 0) {
            SectionHeading(
                title: snapshot.text("home.teaser.title"),
                eyebrow: snapshot.text("home.teaser.eyebrow")
            )

            LazyVGrid(
                columns: isWide
                    ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
                    : [GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(Self.cards, id: \.keyId) { card in
                    teaserCard(card)
                }
            }
            .frame(maxWidth: 720)
            .padding(.top, 40)

            VStack(spacing: 16) {
                Text(snapshot.text("home.cta.text"))
                    .font(AppFont.inter(16))
                    .foregroundStyle(Palette.mutedForeground)
                PrimaryButton(label: snapshot.text("home.cta.label")) {
                    onNavigate(.contact)
                }
            }
            .padding(.top, 44)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    private func teaserCard(_ card: DestinationCard) -> some View {
        Button {
            onNavigate(card.screen)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                AspectImage(
                    src: card.image,
                    aspect: 16.0 / 9.0,
                    contentMode: .fill,
                    contentDescription: snapshot.text("home.card.\(card.keyId).alt")
                )

                VStack(alignment: .leading, spacing: 10) {
                    ScriptTitle(
                        text: snapshot.text("home.card.\(card.keyId).title"),
                        size: 28,
                        alignment: .leading
                    )
                    Text(snapshot.text("home.card.\(card.keyId).blurb"))
                        .font(AppFont.inter(14))
                        .lineSpacing(6)
                        .foregroundStyle(Palette.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(snapshot.text("home.cards.link") + " →")
                        .font(AppFont.interMedium(13))
                        .foregroundStyle(Palette.primary)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}
