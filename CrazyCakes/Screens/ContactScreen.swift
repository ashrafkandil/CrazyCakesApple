import SwiftUI
import UIKit

struct ContactScreen: View {
    let snapshot: ContentSnapshot

    @ObservedObject private var draft = QuoteDraftStore.shared

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var eventType = ""
    @State private var eventDate = ""
    @State private var servings = ""
    @State private var location = ""
    @State private var theme = ""

    @State private var menuOpen = false
    @State private var submitted = false
    @State private var sending = false
    @State private var sendError: String?

    private var supportEmail: String { snapshot.text("contact.email") }
    private var supportPhone: String { snapshot.text("contact.phoneHref") }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPhone: String { phone.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && trimmedEmail.contains("@")
            && !trimmedPhone.isEmpty
            && !eventType.isEmpty
            && !eventDate.trimmingCharacters(in: .whitespaces).isEmpty
            && !servings.trimmingCharacters(in: .whitespaces).isEmpty
            && !theme.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeading(
                        title: snapshot.text("contact.title"),
                        eyebrow: snapshot.text("contact.eyebrow")
                    )

                    Text(snapshot.text("contact.intro"))
                        .font(AppFont.inter(15))
                        .lineSpacing(8)
                        .foregroundStyle(Palette.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                        .padding(.top, 18)
                        .fixedSize(horizontal: false, vertical: true)

                    if isWide {
                        HStack(alignment: .top, spacing: 40) {
                            formCard
                            asideCard
                                .frame(width: 340)
                        }
                        .frame(maxWidth: 980)
                        .padding(.top, 44)
                    } else {
                        VStack(spacing: 32) {
                            formCard
                            asideCard
                        }
                        .frame(maxWidth: 640)
                        .padding(.top, 44)
                    }
                }
                .padding(.vertical, 56)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear(perform: applyDraft)
        .onChange(of: draft.revision) { _ in applyDraft() }
        .sheet(isPresented: $menuOpen) {
            eventTypeSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Draft prefill

    /// The assistant saves quote details; pick them up whenever they change.
    private func applyDraft() {
        let next = draft.read()
        guard !next.isEmpty else { return }
        if let value = next["name"] { name = value }
        if let value = next["email"] { email = value }
        if let value = next["phone"] { phone = value }
        if let value = next["eventType"], snapshot.eventTypes.contains(value) { eventType = value }
        if let value = next["eventDate"] { eventDate = value }
        if let value = next["servings"] { servings = value }
        if let value = next["location"] { location = value }
        if let value = next["theme"] { theme = value }
        submitted = false
    }

    // MARK: - Submit

    private func submit() {
        guard isValid, !sending else { return }
        sending = true
        sendError = nil

        let body = [
            "Name: \(trimmedName)",
            "Email: \(trimmedEmail)",
            "Phone: \(trimmedPhone)",
            "Event type: \(eventType)",
            "Event date: \(eventDate.trimmingCharacters(in: .whitespaces))",
            "Servings: \(servings.trimmingCharacters(in: .whitespaces))",
            "Location: \(location.trimmingCharacters(in: .whitespaces).isEmpty ? "Not specified" : location.trimmingCharacters(in: .whitespaces))",
            "",
            theme.trimmingCharacters(in: .whitespacesAndNewlines),
        ].joined(separator: "\n")

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Custom quote request — \(trimmedName) (\(eventType))"),
            URLQueryItem(name: "body", value: body),
        ]

        guard let url = components.url else {
            sending = false
            sendError = "We could not open your email app. Email \(supportEmail) or call \(snapshot.text("contact.phone")) to send your request."
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                sending = false
                if success {
                    draft.clear()
                    submitted = true
                } else {
                    sendError = "We could not open your email app. Email \(supportEmail) or call \(snapshot.text("contact.phone")) to send your request."
                }
            }
        }
    }

    // MARK: - Cards

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Request a Custom Quote")
                .font(AppFont.serifSemiBold(22))
                .foregroundStyle(Palette.primary)

            if submitted {
                thanks
                    .padding(.top, 24)
            } else {
                VStack(spacing: 14) {
                    field("Name *", text: $name)
                    field("Email *", text: $email, keyboard: .emailAddress, capitalization: .never)
                    field("Phone *", text: $phone, keyboard: .phonePad)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Event Type *")
                            .font(AppFont.interMedium(13))
                            .foregroundStyle(Palette.foreground)

                        if snapshot.eventTypes.isEmpty {
                            field("", text: $eventType, placeholder: "Wedding, Birthday…")
                        } else {
                            Button {
                                menuOpen = true
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
                    }

                    field("Event Date * (YYYY-MM-DD)", text: $eventDate, placeholder: "2026-10-15")
                    field("Number of Servings *", text: $servings, keyboard: .numberPad)
                    field("Event/Delivery Location", text: $location)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tell us more about your theme! *")
                            .font(AppFont.interMedium(13))
                            .foregroundStyle(Palette.foreground)

                        ZStack(alignment: .topLeading) {
                            if theme.isEmpty {
                                Text("Describe the dream cake…")
                                    .font(AppFont.inter(15))
                                    .foregroundStyle(Palette.mutedForeground.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $theme)
                                .font(AppFont.inter(15))
                                .foregroundStyle(Palette.foreground)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .frame(height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Palette.border, lineWidth: 1)
                        )
                    }

                    Button {
                        submit()
                    } label: {
                        Text(sending ? "Opening your email app…" : "Send Inquiry")
                            .font(AppFont.interMedium(15))
                            .foregroundStyle(Palette.primaryForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Palette.primary))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!isValid || sending)
                    .opacity(!isValid || sending ? 0.4 : 1)
                    .padding(.top, 8)

                    if let sendError {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(Palette.primary)
                            Text(sendError)
                                .font(AppFont.inter(13))
                                .lineSpacing(6)
                                .foregroundStyle(Palette.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Palette.primary, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 22)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
    }

    private var asideCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.text("contact.sidebarHeading"))
                .font(AppFont.serifSemiBold(22))
                .foregroundStyle(Palette.primary)

            VStack(alignment: .leading, spacing: 16) {
                Button {
                    open("mailto:\(supportEmail)")
                } label: {
                    infoRow(symbol: "envelope", text: supportEmail)
                }
                .buttonStyle(.plain)

                Button {
                    open("tel:\(supportPhone)")
                } label: {
                    infoRow(symbol: "phone", text: snapshot.text("contact.phone"))
                }
                .buttonStyle(.plain)

                infoRow(
                    symbol: "mappin.and.ellipse",
                    text: snapshot.text("contact.address") + "\n" + snapshot.text("contact.serviceArea")
                )
            }
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                    Text(snapshot.text("contact.followUs"))
                        .font(AppFont.serifSemiBold(18))
                        .foregroundStyle(Palette.foreground)
                }

                FlowLayout(spacing: 8) {
                    ForEach(snapshot.socialLinks) { social in
                        SocialPill(label: social.label, url: social.href)
                    }
                }
            }
            .padding(.top, 28)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.primary)
                Text(snapshot.text("contact.responseNote"))
                    .font(AppFont.inter(13))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.blush))
            .padding(.top, 28)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border, lineWidth: 1))
    }

    private var thanks: some View {
        VStack(spacing: 10) {
            Text("Thank you!")
                .font(AppFont.script(30))
                .foregroundStyle(Palette.primary)
            Text("Your email draft is on its way to \(supportEmail). \(snapshot.text("contact.responseNote"))")
                .font(AppFont.inter(14))
                .foregroundStyle(Palette.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.blush))
    }

    private var eventTypeSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Event Type")
                .font(AppFont.serifSemiBold(18))
                .foregroundStyle(Palette.primary)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(snapshot.eventTypes, id: \.self) { type in
                        Button {
                            eventType = type
                            menuOpen = false
                        } label: {
                            Text(type)
                                .font(AppFont.inter(16))
                                .foregroundStyle(Palette.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .overlay(
                                    Rectangle()
                                        .fill(Palette.border)
                                        .frame(height: 1),
                                    alignment: .bottom
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.card)
    }

    // MARK: - Helpers

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words,
        placeholder: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(AppFont.interMedium(13))
                    .foregroundStyle(Palette.foreground)
            }
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .font(AppFont.inter(15))
                .foregroundStyle(Palette.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Palette.border, lineWidth: 1)
                )
        }
    }

    private func infoRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Palette.primary)
                .frame(width: 20)
            Text(text)
                .font(AppFont.inter(14))
                .lineSpacing(6)
                .foregroundStyle(Palette.mutedForeground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
