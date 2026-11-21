import SwiftUI

struct ReviewsScreen: View {
    let snapshot: ContentSnapshot

    private let instagramReviewsURL = "https://www.instagram.com/marwacrazycakes/"

    @State private var showAddReviewDialog = false
    @State private var reviewName = ""
    @State private var reviewQuote = ""
    @State private var reviewRating = 5
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var submitSuccess = false

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

                        VStack(spacing: 12) {
                            instagramButton
                            addReviewButton
                        }
                        .padding(.top, 32)
                    }
                    .padding(.vertical, 56)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showAddReviewDialog) {
            addReviewSheet
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

    private var instagramButton: some View {
        Group {
            if let url = URL(string: instagramReviewsURL) {
                Link(destination: url) {
                    Text(snapshot.text("reviews.instagramLinkText"))
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

    private var addReviewButton: some View {
        Button(action: {
            showAddReviewDialog = true
            reviewName = ""
            reviewQuote = ""
            reviewRating = 5
            submitError = nil
            submitSuccess = false
        }) {
            Text("Add a review")
                .font(AppFont.interMedium(15))
                .foregroundStyle(Palette.primary)
                .padding(.vertical, 14)
                .padding(.horizontal, 26)
                .background(Capsule().strokeBorder(Palette.border, lineWidth: 1).background(Capsule().fill(Palette.card)))
        }
        .buttonStyle(.plain)
    }

    private var addReviewSheet: some View {
        NavigationStack {
            Form {
                if !submitSuccess {
                    Section(header: Text("Share your review").font(AppFont.serif(20)).foregroundStyle(Palette.primary)) {
                        Text("Your review will be held for moderation before publication.")
                            .font(AppFont.inter(14))
                            .foregroundStyle(Palette.mutedForeground)

                        TextField("Your name", text: $reviewName)
                            .disabled(isSubmitting || submitSuccess)

                        Section(header: Text("Rating").font(AppFont.interMedium(14)).foregroundStyle(Palette.primary)) {
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { reviewRating = star }) {
                                        Image(systemName: star <= reviewRating ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundStyle(star <= reviewRating ? Palette.gold : Palette.mutedForeground)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Section(header: Text("Your review").font(AppFont.interMedium(14)).foregroundStyle(Palette.primary)) {
                            TextEditor(text: $reviewQuote)
                                .frame(minHeight: 120)
                                .disabled(isSubmitting || submitSuccess)
                        }

                        if let error = submitError {
                            Text(error)
                                .font(AppFont.inter(13))
                                .foregroundStyle(.red)
                        }
                    } else {
                        Section {
                            Text("Thank you! Your review has been submitted for moderation.")
                                .font(AppFont.inter(15))
                                .foregroundStyle(Palette.primary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .navigationTitle("Share your review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if !submitSuccess {
                            showAddReviewDialog = false
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitSuccess {
                        Button("Done") {
                            showAddReviewDialog = false
                            submitSuccess = false
                        }
                    } else {
                        Button(isSubmitting ? "Submitting..." : "Submit") {
                            guard !reviewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                submitError = "Please enter your name"
                                return
                            }
                            guard !reviewQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                submitError = "Please enter your review"
                                return
                            }
                            submitError = nil
                            isSubmitting = true

                            Task {
                                let result = await submitReview(
                                    author: reviewName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    quote: reviewQuote.trimmingCharacters(in: .whitespacesAndNewlines),
                                    rating: reviewRating
                                )
                                await MainActor.run {
                                    isSubmitting = false
                                    if result.isSuccess {
                                        submitSuccess = true
                                        reviewName = ""
                                        reviewQuote = ""
                                    } else {
                                        submitError = result.errorMessage ?? "Failed to submit review"
                                    }
                                }
                            }
                        }
                        .disabled(isSubmitting || reviewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reviewQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private func submitReview(author: String, quote: String, rating: Int) async -> ApiClient.SubmitReviewResult {
    return await ApiClient.shared.submitReview(author: author, quote: quote, rating: rating)
}

private var instagramButton: some View {
    Group {
        if let url = URL(string: instagramReviewsURL) {
            Link(destination: url) {
                Text(snapshot.text("reviews.instagramLinkText"))
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

private var addReviewButton: some View {
    Button(action: {
        showAddReviewDialog = true
        reviewName = ""
        reviewQuote = ""
        reviewRating = 5
        submitError = nil
        submitSuccess = false
    }) {
        Text("Add a review")
            .font(AppFont.interMedium(15))
            .foregroundStyle(Palette.primary)
            .padding(.vertical, 14)
            .padding(.horizontal, 26)
            .background(Capsule().strokeBorder(Palette.border, lineWidth: 1).background(Capsule().fill(Palette.card)))
    }
    .buttonStyle(.plain)
}
