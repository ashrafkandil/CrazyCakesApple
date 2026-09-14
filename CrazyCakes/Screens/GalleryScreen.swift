import SwiftUI

struct GalleryScreen: View {
    let onNavigate: (Destination) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var category = "all"
    @State private var page = 1
    @State private var lightbox: LightboxSelection?

    struct LightboxSelection: Identifiable {
        let image: GalleryImage
        let pageImages: [GalleryImage]
        var id: Int { image.id }
    }

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        let gallery = AppDatabase.shared.gallery(
            category: category == "all" ? nil : category,
            page: page
        )
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: isWide ? 3 : 2
        )

        ScrollView {
            VStack(spacing: 32) {
                SectionHeading(title: "Our Gallery", eyebrow: "Portfolio of custom creations")

                Text(
                    "Explore our portfolio of custom creations, each one unique and crafted with passion. From intimate celebrations to grand events, see how we bring visions to life."
                )
                .font(AppFont.inter(15))
                .lineSpacing(8)
                .foregroundStyle(Palette.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(title: "All", slug: "all", active: gallery.activeCategory == "all")
                        ForEach(gallery.categories) { item in
                            chip(title: item.title, slug: item.slug, active: gallery.activeCategory == item.slug)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if gallery.images.isEmpty {
                    Text("No cakes in this category yet — check back soon!")
                        .font(AppFont.inter(15))
                        .foregroundStyle(Palette.mutedForeground)
                        .padding(.vertical, 48)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(gallery.images) { image in
                            Button {
                                lightbox = LightboxSelection(image: image, pageImages: gallery.images)
                            } label: {
                                LocalImage(src: image.src, contentDescription: image.alt)
                                    .frame(height: isWide ? 210 : 150)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Palette.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if gallery.pageCount > 1 {
                    HStack(spacing: 16) {
                        Button {
                            page = max(1, gallery.page - 1)
                        } label: {
                            Text("‹ Previous")
                        }
                        .disabled(gallery.page <= 1)

                        Text("Page \(gallery.page) of \(gallery.pageCount) · \(gallery.total) cakes")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Palette.mutedForeground)

                        Button {
                            page = min(gallery.pageCount, gallery.page + 1)
                        } label: {
                            Text("Next ›")
                        }
                        .disabled(gallery.page >= gallery.pageCount)
                    }
                    .font(AppFont.interMedium(14))
                    .tint(Palette.primary)
                }

                VStack(spacing: 16) {
                    Text("Ready to create your own masterpiece?")
                        .font(AppFont.inter(15))
                        .foregroundStyle(Palette.mutedForeground)
                    Button {
                        onNavigate(.contact)
                    } label: {
                        Text("Start Your Custom Order")
                            .font(AppFont.interMedium(15))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Palette.primary))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 56)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: $lightbox) { selection in
            LightboxView(selection: selection)
        }
    }

    private func chip(title: String, slug: String, active: Bool) -> some View {
        Button {
            category = slug
            page = 1
        } label: {
            Text(title)
                .font(AppFont.interMedium(13))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(active ? Palette.primary : Palette.secondary))
                .foregroundStyle(active ? Palette.primaryForeground : Palette.foreground)
        }
        .buttonStyle(.plain)
    }
}

private struct LightboxView: View {
    let selection: GalleryScreen.LightboxSelection

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(selection: GalleryScreen.LightboxSelection) {
        self.selection = selection
        let initial = selection.pageImages.firstIndex(where: { $0.id == selection.image.id }) ?? 0
        _index = State(initialValue: initial)
    }

    private var current: GalleryImage {
        selection.pageImages[index]
    }

    var body: some View {
        ZStack {
            Palette.overlay.ignoresSafeArea()

            VStack(spacing: 16) {
                LocalImage(src: current.src, contentMode: .fit)
                    .frame(maxWidth: 840, maxHeight: 520)

                Text("\(current.alt) · \(current.categoryTitle)")
                    .font(AppFont.inter(13))
                    .foregroundStyle(Palette.primaryForeground)
                    .multilineTextAlignment(.center)

                HStack(spacing: 24) {
                    Button {
                        index = (index - 1 + selection.pageImages.count) % selection.pageImages.count
                    } label: {
                        Text("‹ Prev")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                    }

                    Button {
                        index = (index + 1) % selection.pageImages.count
                    } label: {
                        Text("Next ›")
                    }
                }
                .font(AppFont.interMedium(14))
                .foregroundStyle(Palette.primaryForeground)
            }
            .padding(24)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryForeground)
                            .padding(10)
                            .background(Circle().fill(Palette.overlaySoft))
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }
}
