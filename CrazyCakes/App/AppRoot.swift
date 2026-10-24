import SwiftUI

/// Adaptive shell: bottom tab bar on phones, sidebar on iPad - the native twin of
/// src/navigation/AppRoot.tsx, including the assistant overlay and watermark.
struct AppRoot: View {
    @ObservedObject var store: ContentStore

    @State private var selection: Destination = .home
    @State private var galleryCategory: String?
    @State private var galleryRevision = 0

    var body: some View {
        GeometryReader { proxy in
            let useSidebar = proxy.size.width >= 720
            ZStack(alignment: .topLeading) {
                Palette.background.ignoresSafeArea()
                WatermarkPattern()

                if useSidebar {
                    sidebarLayout
                } else {
                    phoneLayout
                }

                AssistantView(
                    page: selection.assistantPage,
                    snapshot: store.snapshot,
                    navigate: navigate
                )
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Navigation

    private func navigate(_ screen: Destination, galleryCategory: String? = nil) {
        if screen == .gallery {
            self.galleryCategory = galleryCategory
            // Re-mount the gallery so a fresh assistant request resets category/page.
            galleryRevision += 1
        }
        selection = screen
    }

    @ViewBuilder
    private func screen(for destination: Destination) -> some View {
        switch destination {
        case .home:
            HomeScreen(snapshot: store.snapshot, onNavigate: { navigate($0) })
        case .about:
            AboutScreen(snapshot: store.snapshot, onNavigate: { navigate($0) })
        case .gallery:
            GalleryScreen(
                snapshot: store.snapshot,
                initialCategory: galleryCategory,
                onNavigate: { navigate($0) }
            )
            .id(galleryRevision)
        case .reviews:
            ReviewsScreen(snapshot: store.snapshot)
        case .pricing:
            PricingScreen(snapshot: store.snapshot, onNavigate: { navigate($0) })
        case .contact:
            ContactScreen(snapshot: store.snapshot)
        }
    }

    // MARK: - Phone layout

    private var phoneLayout: some View {
        screen(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabBar
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Palette.card.ignoresSafeArea(edges: .bottom))
                    .overlay(
                        Rectangle()
                            .fill(Palette.border)
                            .frame(height: 1),
                        alignment: .top
                    )
            }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Destination.allCases) { item in
                let active = selection == item
                Button {
                    navigate(item)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22))
                        Text(item.title)
                            .font(active ? AppFont.interSemiBold(10) : AppFont.inter(10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(active ? Palette.primary : Palette.mutedForeground)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - iPad layout

    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.white)
                            LocalImage(src: "/assets/crazy/logo.png", contentMode: .fit)
                                .frame(width: 56, height: 56)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))

                        Text("Marwa Crazy Cakes")
                            .font(AppFont.script(22))
                            .foregroundStyle(Palette.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    ForEach(Destination.allCases) { item in
                        let active = selection == item
                        Button {
                            navigate(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(active ? Palette.primary : Palette.mutedForeground)
                                Text(item.title)
                                    .font(active ? AppFont.interSemiBold(14) : AppFont.interMedium(14))
                                    .foregroundStyle(active ? Palette.primary : Palette.foreground)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(active ? Palette.secondary : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .frame(width: 240)
            .background(Palette.card.ignoresSafeArea())
            .overlay(
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: 1),
                alignment: .trailing
            )

            screen(for: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
