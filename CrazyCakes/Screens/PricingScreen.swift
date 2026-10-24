import SwiftUI

struct PricingScreen: View {
    let snapshot: ContentSnapshot
    let onNavigate: (Destination) -> Void

    private static let priceItems = ["custom", "sculpted", "wedding", "cupcakes"]

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeading(
                        title: snapshot.text("pricing.title"),
                        eyebrow: snapshot.text("pricing.eyebrow")
                    )

                    VStack(spacing: 36) {
                        picture
                        pricingCopy(isWide: isWide)
                    }
                    .padding(.top, 48)
                }
                .frame(maxWidth: 900)
                .padding(.vertical, 56)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var picture: some View {
        AspectImage(
            src: "/assets/crazy/pricing.jpeg",
            aspect: 4.0 / 5.0,
            contentMode: .fill,
            contentDescription: snapshot.text("pricing.imageAlt")
        )
        .frame(maxWidth: 420)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(Palette.muted)
    }

    private func pricingCopy(isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.text("pricing.intro"))
                .font(AppFont.inter(15))
                .lineSpacing(12)
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                Rectangle().fill(Palette.border).frame(height: 1)
                ForEach(Self.priceItems, id: \.self) { item in
                    HStack {
                        Text(snapshot.text("pricing.item.\(item).label"))
                            .font(AppFont.serif(18))
                            .foregroundStyle(Palette.foreground)
                        Spacer()
                        Text(snapshot.text("pricing.item.\(item).price"))
                            .font(AppFont.interBold(15))
                            .foregroundStyle(Palette.primary)
                    }
                    .padding(.vertical, 16)
                    Rectangle().fill(Palette.border).frame(height: 1)
                }
            }
            .padding(.top, 26)

            HStack(spacing: 16) {
                Text(snapshot.text("pricing.quotePrompt"))
                    .font(AppFont.inter(14))
                    .foregroundStyle(Palette.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PrimaryButton(label: snapshot.text("pricing.quoteButton")) {
                    onNavigate(.contact)
                }
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: isWide ? 680 : 560, alignment: .leading)
    }
}
