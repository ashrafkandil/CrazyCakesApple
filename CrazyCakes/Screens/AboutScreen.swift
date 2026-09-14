import SwiftUI

struct AboutScreen: View {
    let onNavigate: (Destination) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let content: [String: String]

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
            VStack(spacing: 44) {
                SectionHeading(
                    title: slot("about.title"),
                    eyebrow: slot("about.eyebrow")
                )

                ScriptTitle(text: slot("about.headline"), size: 34)

                if isWide {
                    HStack(alignment: .center, spacing: 36) {
                        introColumn
                            .frame(maxWidth: .infinity, alignment: .leading)
                        portrait
                            .frame(width: 360)
                    }
                } else {
                    VStack(spacing: 36) {
                        introColumn
                        portrait
                    }
                }

                VStack(spacing: 36) {
                    VStack(spacing: 14) {
                        ScriptTitle(text: slot("about.experienceTitle"), size: 30)
                        bodyParagraph(slot("about.experienceP1"))
                        bodyParagraph(slot("about.experienceP2"))
                    }

                    VStack(spacing: 14) {
                        ScriptTitle(text: slot("about.communityTitle"), size: 30)
                        bodyParagraph(slot("about.communityP1"))
                    }

                    Text(slot("about.quote"))
                        .font(AppFont.serifItalic(16))
                        .foregroundStyle(Palette.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 26)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Palette.card.opacity(0.65))
                        )
                }

                HStack(spacing: 12) {
                    Button {
                        onNavigate(.gallery)
                    } label: {
                        Text(slot("about.cta.gallery"))
                            .font(AppFont.interMedium(15))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .overlay(Capsule().strokeBorder(Palette.primary, lineWidth: 1))
                            .foregroundStyle(Palette.primary)
                    }

                    Button {
                        onNavigate(.contact)
                    } label: {
                        Text(slot("about.cta.contact"))
                            .font(AppFont.interMedium(15))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Palette.primary))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
            }
            .frame(maxWidth: 860)
            .padding(.vertical, 64)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.blush)
    }

    private var introColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(slot("about.intro"))
                .font(AppFont.inter(15))
                .lineSpacing(10)
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(slot("about.introItalic"))
                .font(AppFont.serifItalic(16))
                .lineSpacing(10)
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var portrait: some View {
        LocalImage(src: "/assets/crazy/seema.png", contentMode: .fit)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Palette.primaryForeground, lineWidth: 8)
            )
    }

    private func bodyParagraph(_ text: String) -> some View {
        Text(text)
            .font(AppFont.inter(15))
            .lineSpacing(10)
            .foregroundStyle(Palette.mutedForeground)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
