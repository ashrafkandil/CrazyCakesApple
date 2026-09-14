import SwiftUI
import Combine

struct HomeScreen: View {
    let onNavigate: (Destination) -> Void

    private struct HeroSlide {
        let src: String
        let alt: String
    }

    private struct DestinationCard {
        let screen: Destination
        let imageSrc: String
        let keyId: String
    }

    private static let heroSlides = [
        HeroSlide(src: "/assets/crazy/hero-1.jpg", alt: "Jaw-dropping sculpted cake masterpiece"),
        HeroSlide(src: "/assets/crazy/hero-2.jpg", alt: "Sophisticated multi-tiered wedding cake with edible flowers"),
        HeroSlide(src: "/assets/crazy/hero-3.jpg", alt: "Whimsical sculpted cake with playful design"),
        HeroSlide(src: "/assets/crazy/hero-4.jpg", alt: "Fine edible detailing with sugar flowers and gold leaf"),
    ]

    private static let destinationCards = [
        DestinationCard(screen: .about, imageSrc: "/assets/crazy/seema.png", keyId: "about"),
        DestinationCard(screen: .gallery, imageSrc: "/assets/crazy/celebration-1.jpg", keyId: "gallery"),
        DestinationCard(screen: .reviews, imageSrc: "/assets/crazy/awards.jpg", keyId: "reviews"),
        DestinationCard(screen: .pricing, imageSrc: "/assets/crazy/pricing.jpg", keyId: "pricing"),
    ]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var heroIndex = 0
    private let content: [String: String]
    private let timer = Timer.publish(every: 6.5, on: .main, in: .common).autoconnect()

    init(onNavigate: @escaping (Destination) -> Void) {
        self.onNavigate = onNavigate
        self.content = AppDatabase.shared.content()
    }

    private func slot(_ key: String) -> String {
        AppDatabase.shared.text(in: content, key: key)
    }

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                teasersSection
                BrandFooterView()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var heroSection: some View {
        ZStack {
            TabView(selection: $heroIndex) {
                ForEach(HomeScreen.heroSlides.indices, id: \.self) { index in
                    LocalImage(src: HomeScreen.heroSlides[index].src)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Palette.overlay

            VStack(spacing: 16) {
                Text(slot("home.hero.title"))
                    .font(AppFont.script(isWide ? 52 : 40))
                    .foregroundStyle(Palette.primaryForeground)
                    .multilineTextAlignment(.center)

                Eyebrow(text: slot("home.hero.tagline"), color: Palette.primaryForeground.opacity(0.92))

                Text(slot("home.hero.body"))
                    .font(AppFont.inter(isWide ? 17 : 15))
                    .foregroundStyle(Palette.primaryForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: isWide ? 640 : 360)

                HStack(spacing: 12) {
                    Button {
                        onNavigate(.gallery)
                    } label: {
                        Text(slot("home.hero.cta.gallery"))
                            .font(AppFont.interMedium(15))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Palette.primary))
                            .foregroundStyle(Palette.primaryForeground)
                    }

                    Button {
                        onNavigate(.contact)
                    } label: {
                        Text(slot("home.hero.cta.contact"))
                            .font(AppFont.interMedium(15))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .overlay(
                                Capsule().strokeBorder(Palette.primaryForeground.opacity(0.6), lineWidth: 1)
                            )
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: isWide ? 560 : 480)
        .onReceive(timer) { _ in
            let next = (heroIndex + 1) % HomeScreen.heroSlides.count
            withAnimation { heroIndex = next }
        }
    }

    private var teasersSection: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return VStack(spacing: 40) {
            SectionHeading(
                title: slot("home.teaser.title"),
                eyebrow: slot("home.teaser.eyebrow")
            )

            LazyVGrid(columns: isWide ? columns : [columns[0]], spacing: 16) {
                ForEach(HomeScreen.destinationCards, id: \.keyId) { card in
                    Button {
                        onNavigate(card.screen)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            LocalImage(src: card.imageSrc)
                                .frame(height: 170)
                                .clipped()
                            VStack(alignment: .leading, spacing: 10) {
                                ScriptTitle(
                                    text: slot("home.card.\(card.keyId).title"),
                                    size: 28,
                                    alignment: .leading
                                )
                                Text(slot("home.card.\(card.keyId).blurb"))
                                    .font(AppFont.inter(14))
                                    .foregroundStyle(Palette.mutedForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 8) {
                                    Text(slot("home.cards.link"))
                                        .font(AppFont.interMedium(13))
                                        .foregroundStyle(Palette.primary)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Palette.primary)
                                }
                                .padding(.top, 6)
                            }
                            .padding(24)
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 18) {
                Text(slot("home.cta.text"))
                    .font(AppFont.inter(16))
                    .foregroundStyle(Palette.mutedForeground)
                Button {
                    onNavigate(.contact)
                } label: {
                    Text(slot("home.cta.label"))
                        .font(AppFont.interMedium(15))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Palette.primary))
                        .foregroundStyle(Palette.primaryForeground)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Palette.blush)
    }
}
