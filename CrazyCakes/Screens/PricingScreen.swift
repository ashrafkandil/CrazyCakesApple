import SwiftUI

struct PricingScreen: View {
    let onNavigate: (Destination) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let prices: [(String, String)] = [
        ("Custom Cakes", "$150 & up"),
        ("Sculpted Cakes", "$300 & up"),
        ("Wedding Cakes", "$500 & up"),
        ("Cupcakes (per dozen)", "$40 & up"),
    ]

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                SectionHeading(
                    title: "Cake Pricing",
                    eyebrow: "Thoughtfully designed for your special event"
                )

                let copy = pricingCopy
                let picture = pricingPicture

                if isWide {
                    HStack(alignment: .center, spacing: 40) {
                        copy.frame(maxWidth: .infinity, alignment: .leading)
                        picture.frame(width: 380)
                    }
                } else {
                    VStack(spacing: 36) {
                        copy
                        picture
                    }
                }
            }
            .frame(maxWidth: 900)
            .padding(.vertical, 56)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
    }

    private var pricingCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(
                "Our cakes and other goodies are thoughtfully designed for your special event and are individually priced. To give you an idea of what to expect, we have provided starting prices for each of our products."
            )
            .font(AppFont.inter(15))
            .lineSpacing(10)
            .foregroundStyle(Palette.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                Divider().background(Palette.border)
                ForEach(PricingScreen.prices, id: \.0) { label, price in
                    HStack {
                        Text(label)
                            .font(AppFont.serif(18))
                        Spacer()
                        Text(price)
                            .font(AppFont.interBold(15))
                            .foregroundStyle(Palette.primary)
                    }
                    .padding(.vertical, 16)
                    Divider().background(Palette.border)
                }
            }
            .padding(.top, 26)

            HStack {
                Text("Have something else in mind?")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Palette.mutedForeground)
                Spacer()
                Button {
                    onNavigate(.contact)
                } label: {
                    Text("Get a quote")
                        .font(AppFont.interMedium(14))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Palette.primary))
                        .foregroundStyle(Palette.primaryForeground)
                }
            }
            .padding(.top, 24)
        }
    }

    private var pricingPicture: some View {
        LocalImage(src: "/assets/crazy/pricing.jpg")
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
