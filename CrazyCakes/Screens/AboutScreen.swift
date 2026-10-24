import SwiftUI

struct AboutScreen: View {
    let snapshot: ContentSnapshot
    let onNavigate: (Destination) -> Void

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeading(
                        title: snapshot.text("about.title"),
                        eyebrow: snapshot.text("about.eyebrow")
                    )

                    ScriptTitle(text: snapshot.text("about.headline"), size: 34)
                        .padding(.top, 36)

                    VStack(spacing: 36) {
                        portrait
                        intro
                    }
                    .padding(.top, 44)

                    sections
                        .padding(.top, 56)

                    HStack(spacing: 12) {
                        PrimaryButton(label: snapshot.text("about.cta.gallery"), outline: true) {
                            onNavigate(.gallery)
                        }
                        PrimaryButton(label: snapshot.text("about.cta.contact")) {
                            onNavigate(.contact)
                        }
                    }
                    .padding(.top, 48)
                }
                .frame(maxWidth: isWide ? 900 : 640)
                .padding(.vertical, 64)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var portrait: some View {
        AspectImage(
            src: "/assets/crazy/Marwa.png",
            aspect: 1,
            contentMode: .fill,
            contentDescription: snapshot.text("about.imageAlt")
        )
        .frame(maxWidth: 420)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Palette.card, lineWidth: 8)
        )
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(snapshot.text("about.intro"))
                .font(AppFont.inter(15))
                .lineSpacing(12)
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(snapshot.text("about.introItalic"))
                .font(AppFont.serifItalic(16))
                .lineSpacing(12)
                .foregroundStyle(Palette.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var sections: some View {
        VStack(spacing: 36) {
            VStack(spacing: 14) {
                ScriptTitle(text: snapshot.text("about.experienceTitle"), size: 30)
                Text(snapshot.text("about.experienceP1"))
                    .font(AppFont.inter(15))
                    .lineSpacing(12)
                    .foregroundStyle(Palette.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(snapshot.text("about.experienceP2"))
                    .font(AppFont.inter(15))
                    .lineSpacing(12)
                    .foregroundStyle(Palette.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 14) {
                ScriptTitle(text: snapshot.text("about.communityTitle"), size: 30)
                Text(snapshot.text("about.communityP1"))
                    .font(AppFont.inter(15))
                    .lineSpacing(12)
                    .foregroundStyle(Palette.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(snapshot.text("about.quote"))
                .font(AppFont.serifItalic(16))
                .lineSpacing(12)
                .foregroundStyle(Palette.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.65))
                )
        }
    }
}
