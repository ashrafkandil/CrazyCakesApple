import SwiftUI

struct ContactScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let socials: [(String, String)] = [
        ("Instagram", "https://www.instagram.com/marwacrazycakes/"),
        ("TikTok", "https://www.tiktok.com/@marwacrazycakes"),
        ("X (Twitter)", "https://x.com/marwacrazycakes"),
    ]

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var eventType = ""
    @State private var eventDate = ""
    @State private var servings = ""
    @State private var location = ""
    @State private var theme = ""
    @State private var submitted = false

    private let eventTypes: [String]

    init() {
        self.eventTypes = AppDatabase.shared.eventTypes()
    }

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && !phone.isEmpty
            && !eventType.isEmpty
            && !eventDate.isEmpty
            && !servings.isEmpty
            && !theme.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text("Let\u2019s Create Something Beautiful")
                        .font(AppFont.script(38))
                        .foregroundStyle(Palette.primary)
                        .multilineTextAlignment(.center)
                    Text("READY TO BRING YOUR VISION TO LIFE")
                        .font(AppFont.serif(11))
                        .tracking(2.7)
                        .foregroundStyle(Palette.mutedForeground)
                    Text(
                        "Get in touch to discuss your custom cake needs. We're excited to be part of your special celebration."
                    )
                    .font(AppFont.inter(15))
                    .lineSpacing(8)
                    .foregroundStyle(Palette.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                }

                if isWide {
                    HStack(alignment: .top, spacing: 40) {
                        formCard
                            .frame(maxWidth: .infinity)
                        asideCard
                            .frame(width: 320)
                    }
                } else {
                    VStack(spacing: 32) {
                        formCard
                        asideCard
                    }
                }
            }
            .padding(.vertical, 56)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.blush)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Request a Custom Quote")
                .font(AppFont.serifSemiBold(22))
                .foregroundStyle(Palette.primary)

            if submitted {
                VStack(spacing: 10) {
                    Text("Thank you!")
                        .font(AppFont.script(30))
                        .foregroundStyle(Palette.primary)
                    Text("Your inquiry is ready. We'll be in touch within 24 hours.")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Palette.mutedForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.blush))
            } else {
                VStack(spacing: 14) {
                    field("Name *", text: $name, keyboard: .default)
                    field("Email *", text: $email, keyboard: .emailAddress)
                    field("Phone *", text: $phone, keyboard: .telephonePad)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Event Type *")
                            .font(AppFont.interMedium(13))
                        Menu {
                            ForEach(eventTypes, id: \.self) { type in
                                Button(type) { eventType = type }
                            }
                        } label: {
                            HStack {
                                Text(eventType.isEmpty ? "Select event type" : eventType)
                                    .font(AppFont.inter(15))
                                    .foregroundStyle(eventType.isEmpty ? Palette.mutedForeground : Palette.foreground)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.mutedForeground)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Palette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    field("Event Date * (YYYY-MM-DD)", text: $eventDate, keyboard: .numbersAndPunctuation)
                    field("Number of Servings *", text: $servings, keyboard: .numberPad)
                    field("Event/Delivery Location", text: $location, keyboard: .default)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tell us more about your theme! *")
                            .font(AppFont.interMedium(13))
                        ZStack(alignment: .topLeading) {
                            if theme.isEmpty {
                                Text("Describe the dream cake…")
                                    .font(AppFont.inter(15))
                                    .foregroundStyle(Palette.mutedForeground.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $theme)
                                .font(AppFont.inter(15))
                                .frame(height: 110)
                                .padding(.horizontal, 6)
                                .scrollContentBackground(.hidden)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Palette.border, lineWidth: 1)
                        )
                    }

                    Button {
                        submitted = true
                    } label: {
                        Text("Send Inquiry")
                            .font(AppFont.interMedium(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(isValid ? Palette.primary : Palette.primary.opacity(0.4))
                            )
                            .foregroundStyle(Palette.primaryForeground)
                    }
                    .disabled(!isValid)
                    .padding(.top, 6)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.interMedium(13))
            TextField("", text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .font(AppFont.inter(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Palette.border, lineWidth: 1)
                )
        }
    }

    private var asideCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Get in Touch")
                .font(AppFont.serifSemiBold(22))
                .foregroundStyle(Palette.primary)

            if let mail = URL(string: "mailto:fcabakery@gmail.com") {
                Link(destination: mail) {
                    contactRow(symbol: "envelope", text: "fcabakery@gmail.com")
                }
                .buttonStyle(.plain)
            }
            if let tel = URL(string: "tel:12165718440") {
                Link(destination: tel) {
                    contactRow(symbol: "phone", text: "216.571.8440")
                }
                .buttonStyle(.plain)
            }
            contactRow(
                symbol: "mappin",
                text: "Chagrin Falls, OH 44022\nServing Bainbridge, Solon, Pepper Pike, Twinsburg, Mayfield and nearby areas"
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                    Text("Follow Us")
                        .font(AppFont.serifSemiBold(18))
                }
                HStack(spacing: 8) {
                    ForEach(Array(Self.socials.enumerated()), id: \.offset) { _, social in
                        if let url = URL(string: social.1) {
                            SocialPill(label: social.0, url: url)
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Text(
                    "We'll respond to your inquiry within 24 hours. For urgent requests, please call us directly."
                )
                .font(AppFont.inter(13))
                .lineSpacing(4)
                .foregroundStyle(Palette.mutedForeground)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.blush))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
    }

    private func contactRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.primary)
            Text(text)
                .font(AppFont.inter(14))
                .lineSpacing(4)
                .foregroundStyle(Palette.mutedForeground)
        }
    }
}
