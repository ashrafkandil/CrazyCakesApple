import AVKit
import SwiftUI

struct GalleryScreen: View {
    let snapshot: ContentSnapshot
    let onNavigate: (Destination) -> Void

    @State private var category: String
    @State private var page = 1
    @State private var shuffleSeed: String
    @State private var lightbox: LightboxSelection?
    @State private var videoLightbox: VideoSelection?

    struct LightboxSelection: Identifiable {
        let image: GalleryImage
        let images: [GalleryImage]
        var id: Int { image.id }
    }

    struct VideoSelection: Identifiable {
        let videos: [GalleryVideo]
        let index: Int
        var id: Int { index }
    }

    init(snapshot: ContentSnapshot, initialCategory: String?, onNavigate: @escaping (Destination) -> Void) {
        self.snapshot = snapshot
        self.onNavigate = onNavigate
        _category = State(initialValue: initialCategory ?? "all")
        _shuffleSeed = State(initialValue: ContentSnapshot.makeShuffleSeed())
    }

    private var gallery: GalleryPage {
        snapshot.gallery(category: category == "all" ? nil : category, page: page, shuffleSeed: shuffleSeed)
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 720
            let columns = isWide ? 3 : 2
            let available = min(isWide ? 860 : proxy.size.width - 40, 860)
            let cellSize = max(80, floor((available - 12 * CGFloat(columns - 1)) / CGFloat(columns)))
            let page = gallery

            ScrollView {
                VStack(spacing: 0) {
                    SectionHeading(
                        title: snapshot.text("gallery.title"),
                        eyebrow: snapshot.text("gallery.eyebrow")
                    )

                    Text(snapshot.text("gallery.description"))
                        .font(AppFont.inter(15))
                        .lineSpacing(8)
                        .foregroundStyle(Palette.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 720)
                        .padding(.top, 18)
                        .fixedSize(horizontal: false, vertical: true)

                    chips(page: page)
                        .padding(.top, 32)

                    if page.images.isEmpty {
                        Text(snapshot.text("gallery.empty"))
                            .font(AppFont.inter(15))
                            .foregroundStyle(Palette.mutedForeground)
                            .padding(.vertical, 48)
                    } else {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 12),
                                count: columns
                            ),
                            spacing: 12
                        ) {
                            ForEach(page.images) { image in
                                imageTile(image, cellSize: cellSize, page: page)
                            }
                        }
                        .frame(maxWidth: 900)
                        .padding(.top, 32)
                    }

                    if page.pageCount > 1 {
                        pagination(page: page)
                            .padding(.top, 28)
                    }

                    if !page.videos.isEmpty {
                        videoSection(page: page, cellSize: cellSize)
                            .padding(.top, 52)
                    }

                    VStack(spacing: 16) {
                        Text(snapshot.text("gallery.ctaText"))
                            .font(AppFont.inter(15))
                            .foregroundStyle(Palette.mutedForeground)
                        PrimaryButton(label: snapshot.text("gallery.ctaLabel")) {
                            onNavigate(.contact)
                        }
                    }
                    .padding(.top, 44)
                }
                .padding(.vertical, 56)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
            .fullScreenCover(item: $videoLightbox) { selection in
                GalleryVideoLightboxView(snapshot: snapshot, selection: selection)
            }
        }
        .fullScreenCover(item: $lightbox) { selection in
            GalleryLightboxView(snapshot: snapshot, selection: selection)
        }
    }

    private struct GalleryChip: Identifiable {
        let id: String
        let title: String
    }

    private func chips(page: GalleryPage) -> some View {
        VStack(spacing: 8) {
            let items: [GalleryChip] =
                [GalleryChip(id: "all", title: snapshot.text("gallery.allCategory"))]
                + page.categories.map { GalleryChip(id: $0.slug, title: $0.title) }

            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    let active = page.activeCategory == item.id
                    Button {
                        category = item.id
                        self.page = 1
                        if item.id == "all" {
                            shuffleSeed = ContentSnapshot.makeShuffleSeed()
                        }
                    } label: {
                        Text(item.title)
                            .font(AppFont.interMedium(13))
                            .foregroundStyle(active ? Palette.primaryForeground : Palette.foreground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(active ? Palette.primary : Palette.secondary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func imageTile(_ image: GalleryImage, cellSize: CGFloat, page: GalleryPage) -> some View {
        Button {
            lightbox = LightboxSelection(image: image, images: page.images)
        } label: {
            ZStack {
                Palette.muted
                WatermarkPattern(tileSize: 48, opacity: 0.08)
                LocalImage(src: image.src, contentDescription: image.alt, contentMode: .fit)
            }
            .frame(height: (cellSize * 3 / 4).rounded())
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Palette.foreground, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func pagination(page: GalleryPage) -> some View {
        HStack(spacing: 16) {
            Button {
                self.page = max(1, page.page - 1)
            } label: {
                Text(snapshot.text("gallery.previous"))
                    .font(AppFont.interMedium(14))
                    .foregroundStyle(page.page <= 1 ? Palette.mutedForeground.opacity(0.5) : Palette.primary)
            }
            .disabled(page.page <= 1)
            .buttonStyle(.plain)

            Text(
                snapshot.text("gallery.pageStatus")
                    .replacingOccurrences(of: "{page}", with: String(page.page))
                    .replacingOccurrences(of: "{pageCount}", with: String(page.pageCount))
                    .replacingOccurrences(of: "{total}", with: String(page.total))
            )
            .font(AppFont.inter(13))
            .foregroundStyle(Palette.mutedForeground)

            Button {
                self.page = min(page.pageCount, page.page + 1)
            } label: {
                Text(snapshot.text("gallery.next"))
                    .font(AppFont.interMedium(14))
                    .foregroundStyle(page.page >= page.pageCount ? Palette.mutedForeground.opacity(0.5) : Palette.primary)
            }
            .disabled(page.page >= page.pageCount)
            .buttonStyle(.plain)
        }
    }

    private func videoSection(page: GalleryPage, cellSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            SectionHeading(
                title: snapshot.text("gallery.videoTitle"),
                eyebrow: snapshot.text("gallery.videoEyebrow")
            )

            Text(snapshot.text("gallery.videoDescription"))
                .font(AppFont.inter(15))
                .lineSpacing(8)
                .foregroundStyle(Palette.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: cellSize, maximum: cellSize + 40), spacing: 12)],
                spacing: 12
            ) {
                ForEach(page.videos.indices, id: \.self) { index in
                    videoTile(page.videos[index], cellSize: cellSize, page: page, index: index)
                }
            }
        }
        .padding(.top, 36)
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func videoTile(_ video: GalleryVideo, cellSize: CGFloat, page: GalleryPage, index: Int) -> some View {
        let poster = video.categorySlug == "wedding"
            ? "/assets/crazy/Wedding/0_IMG_4922.JPEG"
            : "/assets/crazy/Celebrations/0_IMG_3530.JPEG"

        return Button {
            videoLightbox = VideoSelection(videos: page.videos, index: index)
        } label: {
            ZStack(alignment: .bottom) {
                Palette.muted
                LocalImage(src: poster, contentDescription: video.title, contentMode: .fill)
                WatermarkPattern(tileSize: 48, opacity: 0.08)
                Palette.overlaySoft
                Image(systemName: "play.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(Palette.primaryForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                Text(video.title)
                    .font(AppFont.interMedium(12))
                    .foregroundStyle(Palette.primaryForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.overlaySoft)
            }
            .frame(height: (cellSize * 3 / 4).rounded())
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Palette.foreground, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(video.title)
    }
}

// MARK: - Image lightbox

private struct GalleryLightboxView: View {
    let snapshot: ContentSnapshot
    let selection: GalleryScreen.LightboxSelection

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(snapshot: ContentSnapshot, selection: GalleryScreen.LightboxSelection) {
        self.snapshot = snapshot
        self.selection = selection
        let initial = selection.images.firstIndex(where: { $0.id == selection.image.id }) ?? 0
        _index = State(initialValue: max(0, initial))
    }

    private var current: GalleryImage? {
        selection.images.indices.contains(index) ? selection.images[index] : nil
    }

    var body: some View {
        ZStack {
            Palette.overlayStrong.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("\(current?.alt ?? "") · \(current?.categoryTitle ?? "")")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Palette.primaryForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        dismiss()
                    } label: {
                        Text("✕ " + snapshot.text("gallery.closeImage"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)

                TabView(selection: $index) {
                    ForEach(selection.images.indices, id: \.self) { offset in
                        LocalImage(
                            src: selection.images[offset].src,
                            contentDescription: selection.images[offset].alt,
                            contentMode: .fit
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 32) {
                    Button {
                        step(-1)
                    } label: {
                        Text(snapshot.text("gallery.previousImage"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                    Button {
                        step(1)
                    } label: {
                        Text(snapshot.text("gallery.nextImage"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func step(_ delta: Int) {
        guard !selection.images.isEmpty else { return }
        withAnimation {
            index = (index + delta + selection.images.count) % selection.images.count
        }
    }
}

// MARK: - Video lightbox

private struct GalleryVideoLightboxView: View {
    let snapshot: ContentSnapshot
    let selection: GalleryScreen.VideoSelection

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(snapshot: ContentSnapshot, selection: GalleryScreen.VideoSelection) {
        self.snapshot = snapshot
        self.selection = selection
        _index = State(initialValue: selection.index)
    }

    private var current: GalleryVideo? {
        selection.videos.indices.contains(index) ? selection.videos[index] : nil
    }

    var body: some View {
        ZStack {
            Palette.overlayStrong.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("\(current?.title ?? "") · \(current?.categoryTitle ?? "")")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Palette.primaryForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        dismiss()
                    } label: {
                        Text("✕ " + snapshot.text("gallery.closeVideo"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)

                if let current {
                    CraftVideoPlayer(src: current.src)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 32) {
                    Button {
                        step(-1)
                    } label: {
                        Text(snapshot.text("gallery.previousVideo"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                    Button {
                        step(1)
                    } label: {
                        Text(snapshot.text("gallery.nextVideo"))
                            .font(AppFont.interMedium(14))
                            .foregroundStyle(Palette.primaryForeground)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func step(_ delta: Int) {
        guard !selection.videos.isEmpty else { return }
        index = (index + delta + selection.videos.count) % selection.videos.count
    }
}

/// Plays the published clip when the content host serves it, otherwise the bundled copy.
private struct CraftVideoPlayer: View {
    let src: String

    @State private var player = AVPlayer()
    @State private var observation: NSKeyValueObservation?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { start() }
            .onDisappear {
                observation?.invalidate()
                observation = nil
                player.pause()
            }
            .onChange(of: src) { _ in start() }
    }

    private func start() {
        let remote = MediaLibrary.shared.remoteURL(for: src)
        let bundled = MediaLibrary.shared.bundledVideoURL(for: src)
        guard let url = remote ?? bundled else { return }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()

        observation?.invalidate()
        guard remote != nil, let bundled else { return }
        observation = item.observe(\.status, options: [.new]) { observed, _ in
            guard observed.status == .failed else { return }
            DispatchQueue.main.async {
                player.replaceCurrentItem(with: AVPlayerItem(url: bundled))
                player.play()
            }
        }
    }
}

// MARK: - Chip wrapping layout

/// A minimal wrapping HStack, so category chips wrap like the React Native flexWrap row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(width: min(widestRow, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
