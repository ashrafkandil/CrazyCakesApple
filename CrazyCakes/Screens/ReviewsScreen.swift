import SwiftUI

struct ReviewsScreen: View {
    let snapshot: ContentSnapshot

    private let googleReviewsURL = "https://www.google.com/search?q=Marwa+Crazy+Cakes+Reviews"

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            ScrollView {
                VStack(spacing: 0) {
                    banner(isWide: isWide)

                    VStack(spacing: 0) {
                        Text(snapshot.text("reviews.intro"))
                            .font(AppFont.inter(15))
                            .lineSpacing(12)
                            .foregroundStyle(Palette.mutedForeground)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 720)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 10) {
                            Text(snapshot.text("reviews.sectionTitle"))
                                .font(AppFont.serifItalic(26))
                                .foregroundStyle(Palette.primary)
                            Text(snapshot.text("reviews.sectionSubtitle"))
                                .font(AppFont.inter(15))
                                .foregroundStyle(Palette.mutedForeground)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 44)

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 14),
                                count: isWide ? 3 : 1
                            ),
                            spacing: 14
                        ) {
                            ForEach(snapshot.testimonials) { review in
                                testimonialCard(review)
                            }
                        }
                        .frame(maxWidth: 900)
                        .padding(.top, 28)

                        googleButton
                            .padding(.top, 32)
                    }
                    .padding(.vertical, 56)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func banner(isWide: Bool) -> some View {
        ZStack {
            LocalImage(
                src: "/assets/crazy/Testimony.png",
                contentDescription: snapshot.text("reviews.hero.title"),
                contentMode: .fill
            )

            Palette.overlay

            VStack(spacing: 12) {
                Text(snapshot.text("reviews.hero.title"))
                    .font(AppFont.script(isWide ? 44 : 36))
                    .foregroundStyle(Palette.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot.text("reviews.hero.subtitle").uppercased())
                    .font(AppFont.serif(11))
                    .tracking(Metrics.eyebrowLetterSpacing)
                    .foregroundStyle(Palette.primary)
                    .multilineTextAlignment(.center)

                Text(snapshot.text("reviews.hero.body"))
                    .font(AppFont.inter(16))
                    .foregroundStyle(Palette.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: isWide ? 320 : 260)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Palette.muted)
    }

    private func testimonialCard(_ review: Testimonial) -> some View {
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
        .cardShadow()
    }

    private var googleButton: some View {
        Group {
            if let url = URL(string: googleReviewsURL) {
                Link(destination: url) {
                    Text(snapshot.text("reviews.googleLinkText"))
                        .font(AppFont.interMedium(15))
                        .foregroundStyle(Palette.primaryForeground)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 26)
                        .background(Capsule().fill(Palette.primary))
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }
}
