import Combine
import SwiftUI

struct ChatMessage: Identifiable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id: String
    let role: Role
    var text: String
    var notes: [String] = []
    var pending = false
}

/// The floating Sprinkles assistant - the native twin of AvatarAssistant.tsx.
@MainActor
final class AssistantModel: ObservableObject {
    @Published var open = false
    @Published var messages: [ChatMessage] = []
    @Published var suggestions: [String] = []
    @Published var input = ""
    @Published var mood: AssistantMood = .idle
    @Published var busy = false
    @Published var lang: Lang = .en
    @Published var voiceOn = true
    @Published var notice: String?
    @Published var welcomed = false
    @Published var introDone = false

    let recorder = VoiceRecorder()
    private var cancellables = Set<AnyCancellable>()

    private var page: AssistantPage = .home
    private var snapshot: ContentSnapshot = .empty
    private var navigate: ((Destination, String?) -> Void)?

    var copy: AssistantCopy { AssistantCopy.copy(for: lang) }

    init() {
        // Re-publish the recorder's state so the panel updates while recording.
        recorder.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        recorder.onClip = { [weak self] clip in
            Task { @MainActor in await self?.sendClip(clip) }
        }
        recorder.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.notice = self.copy.voiceErrors[error]
            }
        }
    }

    func configure(page: AssistantPage, snapshot: ContentSnapshot, navigate: @escaping (Destination, String?) -> Void) {
        self.page = page
        self.snapshot = snapshot
        self.navigate = navigate
    }

    // MARK: - Conversation

    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await transmit(text: trimmed, clip: nil)
    }

    func sendClip(_ clip: VoiceClip) async {
        await transmit(text: "", clip: clip)
    }

    private func transmit(text: String, clip: VoiceClip?) async {
        guard !busy else { return }
        let copy = self.copy

        stopSpeakingAll()
        notice = nil
        suggestions = []

        let history = messages.filter { !$0.pending }
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            text: clip == nil ? text : copy.voicePending,
            pending: clip != nil
        )
        messages = history + [userMessage]
        input = ""
        busy = true
        mood = .thinking

        do {
            let source = clip == nil ? messages : history
            let turns = source.suffix(12).map { message in
                ChatTurn(role: message.role == .assistant ? "assistant" : "user", text: message.text)
            }
            let request = AssistantRequest(messages: Array(turns), audio: clip, page: page, lang: lang)
            let data = try await AssistantClient.ask(request, snapshot: snapshot)

            if clip != nil {
                let heard = (data.heard?.isEmpty == false) ? data.heard! : copy.voiceUnclear
                if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                    messages[index] = ChatMessage(id: userMessage.id, role: .user, text: heard)
                }
            }

            let notes = runActions(data.actions)
            var reply = ChatMessage(id: UUID().uuidString, role: .assistant, text: data.reply)
            reply.notes = notes
            messages.append(reply)
            suggestions = data.suggestions
            speakReply(data.reply)
        } catch {
            if clip != nil {
                messages.removeAll { $0.id == userMessage.id }
            }
            notice = error.localizedDescription
        }

        busy = false
        if mood == .thinking {
            mood = .idle
        }
    }

    /// Runs the model's safe actions: open a screen, jump to a gallery category, or
    /// pre-fill the quote form. Returns the notes shown under the reply bubble.
    private func runActions(_ actions: [AssistantAction]) -> [String] {
        var notes: [String] = []
        var destination: Destination?
        var galleryCategory: String?

        for action in actions {
            switch action {
            case .navigate(let page):
                destination = page.destination
                notes.append("Opened \(page.label)")
            case .showGalleryCategory(let slug, let title):
                destination = .gallery
                galleryCategory = slug
                notes.append("Showing \(title)")
            case .prefillQuote(let quote):
                QuoteDraftStore.shared.write(quote)
                destination = .contact
                notes.append("Filled in your quote request. Please review it")
            }
        }

        if let destination {
            navigate?(destination, galleryCategory)
        }
        return notes
    }

    // MARK: - Voice + speech

    func speakReply(_ text: String) {
        guard voiceOn else { return }
        AssistantSpeech.shared.speak(
            text,
            onStart: { [weak self] in self?.mood = .speaking },
            onDone: { [weak self] in
                guard let self else { return }
                if self.mood == .speaking { self.mood = .idle }
            }
        )
    }

    func stopSpeakingAll() {
        AssistantSpeech.shared.stop()
        if mood == .speaking { mood = .idle }
    }

    func toggleMic() {
        if recorder.recording {
            recorder.stop()
            return
        }
        stopSpeakingAll()
        notice = nil
        open = true
        guard AssistantClient.isConfigured() else {
            notice = copy.failed
            return
        }
        recorder.start()
    }

    func openChat() {
        open = true
        if !welcomed && messages.isEmpty {
            welcomed = true
            speakReply(copy.greeting)
        }
    }

    func reset() {
        stopSpeakingAll()
        recorder.cancel()
        messages = []
        suggestions = []
        notice = nil
        input = ""
    }

    func toggleLanguage() {
        lang = lang == .en ? .ar : .en
    }

    func toggleVoice() {
        if voiceOn { stopSpeakingAll() }
        voiceOn.toggle()
    }
}

@MainActor
struct AssistantView: View {
    let page: AssistantPage
    let snapshot: ContentSnapshot
    let navigate: (Destination, String?) -> Void

    @StateObject private var model = AssistantModel()
    @State private var intro: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                if model.open {
                    panel(size: proxy.size)
                        .padding(.trailing, 12)
                        .padding(.bottom, 96)
                }

                avatarButton(size: proxy.size)
                    .padding(.trailing, 16)
                    .padding(.bottom, 84)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onAppear {
            model.configure(page: page, snapshot: snapshot, navigate: navigate)
            withAnimation(.easeOut(duration: 0.9)) { intro = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                model.introDone = true
            }
        }
        .onChange(of: page) { _ in
            model.configure(page: page, snapshot: snapshot, navigate: navigate)
        }
        .onChange(of: snapshot.version) { _ in
            model.configure(page: page, snapshot: snapshot, navigate: navigate)
        }
    }

    // MARK: - Floating avatar

    private func avatarButton(size: CGSize) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !model.introDone {
                Text("AI assistance")
                    .font(AppFont.interMedium(12))
                    .foregroundStyle(Palette.primaryForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.primary))
            }

            Button {
                if model.open {
                    model.open = false
                } else {
                    model.openChat()
                }
            } label: {
                ZStack {
                    Circle().fill(Palette.background)
                    Circle().strokeBorder(Palette.primary, lineWidth: 2)
                    if model.open {
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Palette.primary)
                    } else {
                        AssistantAvatar(mood: model.mood, size: 60)
                    }
                }
                .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.open ? "Close assistant" : "Chat with Sprinkles")
        }
        .offset(y: (1 - intro) * max(0, size.height / 2 - 116))
        .scaleEffect(1 + 0.6 * (1 - intro))
        .opacity(Double(intro))
    }

    // MARK: - Panel

    private func panel(size: CGSize) -> some View {
        VStack(spacing: 0) {
            header
            conversation
            if !chips.isEmpty && !model.busy && !model.recorder.recording {
                chipRow
            }
            inputRow
            Text(model.copy.disclaimer)
                .font(AppFont.inter(10))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.mutedForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: min(390, max(240, size.width - 24)), height: min(620, max(320, size.height - 140)))
        .background(Palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.border, lineWidth: 1))
        .transition(.opacity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Palette.background)
                Circle().strokeBorder(
                    model.mood == .speaking ? Palette.secondary : Palette.primary,
                    lineWidth: model.mood == .listening ? 3 : 1
                )
                AssistantAvatar(mood: model.mood, size: 54)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sprinkles")
                    .font(AppFont.serifSemiBold(18))
                    .foregroundStyle(Palette.primary)
                Text(model.copy.status(model.mood))
                    .font(AppFont.inter(12))
                    .foregroundStyle(Palette.mutedForeground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                iconButton("character.book.closed", label: "Switch language") {
                    model.toggleLanguage()
                }
                iconButton(
                    model.voiceOn ? "speaker.wave.2" : "speaker.slash",
                    label: model.voiceOn ? "Mute voice" : "Turn voice on"
                ) {
                    model.toggleVoice()
                }
                iconButton("arrow.clockwise", label: "Start over") {
                    model.reset()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.blush)
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
    }

    private var conversation: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(displayMessages) { message in
                        bubble(message)
                    }
                    if model.busy {
                        thinkingBubble
                    }
                    if let notice = model.notice {
                        Text(notice)
                            .font(AppFont.inter(12))
                            .lineSpacing(4)
                            .foregroundStyle(Palette.foreground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Palette.blush)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.border, lineWidth: 1))
                            )
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.messages.count) { _ in scrollToBottom(scroller) }
            .onChange(of: model.busy) { _ in scrollToBottom(scroller) }
            .onChange(of: model.notice) { _ in scrollToBottom(scroller) }
            .onChange(of: model.open) { _ in scrollToBottom(scroller) }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToBottom(_ scroller: ScrollViewProxy) {
        withAnimation {
            scroller.scrollTo("bottom", anchor: .bottom)
        }
    }

    private var displayMessages: [ChatMessage] {
        if model.messages.isEmpty {
            return [ChatMessage(id: "greeting", role: .assistant, text: model.copy.greeting)]
        }
        return model.messages
    }

    private var chips: [String] {
        model.messages.isEmpty ? model.copy.starters : model.suggestions
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack(spacing: 0) {
            if message.role == .user { Spacer(minLength: 28) }

            VStack(alignment: .leading, spacing: 0) {
                Text(message.text)
                    .font(AppFont.inter(14))
                    .lineSpacing(5)
                    .foregroundStyle(message.role == .user ? Palette.primaryForeground : Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(message.notes, id: \.self) { note in
                    Text("✓ \(note)")
                        .font(AppFont.interMedium(12))
                        .foregroundStyle(Palette.primary)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                BubbleShape(isUser: message.role == .user)
                    .fill(message.role == .user ? Palette.primary : Palette.muted)
            )
            .opacity(message.pending ? 0.7 : 1)

            if message.role == .assistant { Spacer(minLength: 28) }
        }
        .frame(maxWidth: .infinity)
    }

    private var thinkingBubble: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Palette.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                BubbleShape(isUser: false)
                    .fill(Palette.muted)
            )
            Spacer(minLength: 28)
        }
    }

    private var chipRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(chips, id: \.self) { chip in
                Button {
                    Task { await model.sendText(chip) }
                } label: {
                    Text(chip)
                        .font(AppFont.inter(12))
                        .foregroundStyle(Palette.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule().strokeBorder(Palette.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                model.toggleMic()
            } label: {
                Image(systemName: model.recorder.recording ? "stop.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundStyle(model.recorder.recording ? Palette.primaryForeground : Palette.primary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(model.recorder.recording ? Palette.primary : Palette.secondary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.busy)
            .accessibilityLabel(model.recorder.recording ? "Stop and send" : "Talk")

            if model.recorder.recording {
                HStack(spacing: 10) {
                    LevelBars(level: model.recorder.level)
                    Text(model.recorder.hearingVoice ? model.copy.hearing : model.copy.speakNow)
                        .font(AppFont.interMedium(12))
                        .foregroundStyle(Palette.foreground)
                        .lineLimit(1)
                    Text("\(model.recorder.seconds)s")
                        .font(AppFont.inter(12))
                        .foregroundStyle(Palette.mutedForeground)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.blush))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.primary, lineWidth: 1))

                Button {
                    model.recorder.cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")
            } else {
                TextField(model.copy.placeholder, text: $model.input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(AppFont.inter(14))
                    .foregroundStyle(Palette.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Palette.border, lineWidth: 1)
                    )

                Button {
                    Task { await model.sendText(model.input) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.primaryForeground)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Palette.primary))
                }
                .buttonStyle(.plain)
                .disabled(model.busy || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(model.busy || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .top)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Palette.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct LevelBars: View {
    let level: Double
    private let weights: [Double] = [0.5, 0.8, 1, 0.8, 0.5]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<weights.count, id: \.self) { index in
                Capsule()
                    .fill(Palette.primary)
                    .frame(width: 3, height: CGFloat(4 + level * weights[index] * 20))
            }
        }
        .frame(height: 24)
    }
}

/// Bubble with one squared-off corner, like the React Native chat bubbles.
private struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 16
        let small: CGFloat = 3
        let topLeft: CGFloat = big
        let topRight: CGFloat = big
        let bottomLeft: CGFloat = isUser ? big : small
        let bottomRight: CGFloat = isUser ? small : big

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
            radius: topRight,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
            radius: bottomRight,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(
            center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
            radius: topLeft,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
