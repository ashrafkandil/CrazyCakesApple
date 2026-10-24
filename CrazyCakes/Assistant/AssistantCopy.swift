import Foundation

/// The screens Sprinkles can report and open - the native twin of AssistantPage in
/// src/assistant/shared.ts.
enum AssistantPage: String, CaseIterable {
    case home = "/"
    case about = "/about"
    case gallery = "/gallery"
    case reviews = "/reviews"
    case pricing = "/pricing"
    case contact = "/contact"

    var label: String {
        switch self {
        case .home: return "Home"
        case .about: return "About Us"
        case .gallery: return "Gallery"
        case .reviews: return "Reviews"
        case .pricing: return "Pricing"
        case .contact: return "Quote request form"
        }
    }

    var destination: Destination {
        switch self {
        case .home: return .home
        case .about: return .about
        case .gallery: return .gallery
        case .reviews: return .reviews
        case .pricing: return .pricing
        case .contact: return .contact
        }
    }

    static func from(path: String) -> AssistantPage? {
        AssistantPage(rawValue: path)
    }
}

enum Lang: String {
    case en
    case ar
}

enum VoiceError: String {
    case denied
    case noMic = "no-mic"
    case unsupported
    case noSpeech = "no-speech"
    case failed
}

struct AssistantCopy {
    let greeting: String
    let starters: [String]
    let placeholder: String
    let disclaimer: String
    let statusIdle: String
    let statusListening: String
    let statusThinking: String
    let statusSpeaking: String
    let speakNow: String
    let hearing: String
    let voicePending: String
    let voiceUnclear: String
    let failed: String
    let voiceErrors: [VoiceError: String]

    func status(_ mood: AssistantMood) -> String {
        switch mood {
        case .idle: return statusIdle
        case .listening: return statusListening
        case .thinking: return statusThinking
        case .speaking: return statusSpeaking
        }
    }

    /// Same table as COPY in src/assistant/shared.ts.
    static let en = AssistantCopy(
        greeting: "Hi! Welcome to Marwa Crazy Cakes. How can I help you today?",
        starters: ["Show me wedding cakes", "How much is a custom cake?", "I need a birthday cake"],
        placeholder: "Type a message...",
        disclaimer: "AI assistant. It can make mistakes; final prices are confirmed by quote.",
        statusIdle: "Online · tap the mic and just talk",
        statusListening: "Listening...",
        statusThinking: "Thinking...",
        statusSpeaking: "Speaking...",
        speakNow: "Listening... speak now",
        hearing: "I hear you! I'll answer when you pause",
        voicePending: "🎤 Voice message...",
        voiceUnclear: "🎤 (voice message)",
        failed: "Sorry, something went wrong. Please try again.",
        voiceErrors: [
            .denied: "Microphone access is blocked. Enable it for this app in your settings, then tap the mic again.",
            .noMic: "I couldn't find a microphone. Check your sound settings.",
            .unsupported: "Voice isn't available on this device. You can always type instead.",
            .noSpeech: "I didn't hear anything. Check that your mic isn't muted, then tap the mic and speak.",
            .failed: "I couldn't record your voice just now. Please try again or type instead.",
        ]
    )

    static let ar = AssistantCopy(
        greeting: "مرحباً! أهلاً بك في Marwa Crazy Cakes. كيف يمكنني مساعدتك اليوم؟",
        starters: ["أرني كعكات الزفاف", "كم سعر الكعكة المخصصة؟", "أحتاج كعكة عيد ميلاد"],
        placeholder: "اكتب رسالة...",
        disclaimer: "مساعد ذكي وقد يخطئ؛ السعر النهائي يُؤكَّد عبر عرض السعر.",
        statusIdle: "متصلة · اضغط الميكروفون وتحدّث",
        statusListening: "أستمع...",
        statusThinking: "أفكر...",
        statusSpeaking: "أتحدث...",
        speakNow: "أستمع... تحدّث الآن",
        hearing: "أسمعك! سأجيب عندما تتوقف",
        voicePending: "🎤 رسالة صوتية...",
        voiceUnclear: "🎤 (رسالة صوتية)",
        failed: "عذراً، حدث خطأ. حاول مرة أخرى.",
        voiceErrors: [
            .denied: "تم حظر الميكروفون. فعّله من إعدادات التطبيق ثم اضغط الميكروفون مرة أخرى.",
            .noMic: "لم أجد ميكروفوناً. تحقق من إعدادات الصوت.",
            .unsupported: "الصوت غير متاح على هذا الجهاز. يمكنك الكتابة بدلاً من ذلك.",
            .noSpeech: "لم أسمع شيئاً. تأكد أن الميكروفون غير مكتوم ثم حاول مرة أخرى.",
            .failed: "تعذّر تسجيل صوتك الآن. حاول مرة أخرى أو اكتب رسالتك.",
        ]
    )

    static func copy(for lang: Lang) -> AssistantCopy {
        lang == .ar ? .ar : .en
    }

    /// Arabic script block, used to pick the speaking voice (ARABIC in shared.ts).
    static func containsArabic(_ text: String) -> Bool {
        text.range(of: "[\u{0600}-\u{06FF}]", options: .regularExpression) != nil
    }
}

/// Avatar mood - the same states the React Native widget drives.
enum AssistantMood: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}
