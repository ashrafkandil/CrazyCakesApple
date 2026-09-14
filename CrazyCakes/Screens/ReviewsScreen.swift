import SwiftUI

struct ReviewsScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let testimonials: [Testimonial]

    init() {
        self.testimonials = AppDatabase.shared.testimonials()
    }

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                banner
                VStack(spacing: 36) {
                    Text(
                        "Founded by Seema Acharya, Marwa Crazy Cakes in Chagrin Falls, OH has been honored with national awards, television appearances, and features in leading publications. Our clients' testimonials are a testament to artistry, innovation, and dedication to crafting unforgettable cakes."
                    )
                    .font(AppFont.inter(15))
                    .lineSpacing(10)
                    .foregroundStyle(Palette.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 720)

                    VStack(spacing: 10) {
                        Text("Client Reviews")
                            .font(AppFont.serifItalic(26))
                            .foregroundStyle(Palette.primary)
                        Text("Hear what our clients say about their experience with Marwa Crazy Cakes")
                            .font(AppFont.inter(15))
                            .foregroundStyle(Palette.mutedForeground)
                            .multilineTextAlignment(.center)
                    }

                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 14),
                            count: isWide ? 3 : 1
                        ),
                        spacing: 14
                    ) {
                        ForEach(testimonials) { review in
                            TestimonialCard(review: review)
                        }
                    }

                    if let url = URL(string: "https://www.google.com/search?q=Marwa+Crazy+Cakes+Reviews") {
                        Link(destination: url) {
                            Text("★ Read More Reviews on Google ★")
                                .font(AppFont.interMedium(15))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Palette.primary))
                                .foregroundStyle(Palette.primaryForeground)
                        }
                    }
                }
                .padding(.vertical, 56)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Palette.blush)
            }
        }
    }

    private var banner: some View {
        ZStack {
            LocalImage(src: "/assets/crazy/awards.jpg")
                .frame(maxWidth: .infinity)
                .frame(height: isWide ? 320 : 260)
                .clipped()

            Palette.overlay

            VStack(spacing: 14) {
                Text("Reviews & Testimonials")
                    .font(AppFont.script(isWide ? 44 : 36))
                    .foregroundStyle(Palette.primaryForeground)
                Text("CELEBRATING EXCELLENCE IN SUGAR ARTISTRY")
                    .font(AppFont.serif(11))
                    .tracking(2.7)
                    .foregroundStyle(Palette.primaryForeground.opacity(0.9))
                Text("Our dedication to craft is celebrated across every platform and occasion.")
                    .font(AppFont.inter(16))
                    .foregroundStyle(Palette.primaryForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: isWide ? 320 : 260)
    }
}

struct TestimonialCard: View {
    let review: Testimonial

    var body: some View {
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
                .lineSpacing(8)
                .italic()
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
    }
}
