import AVFoundation
import Foundation

/// Text-to-speech with the device voices - the native twin of expo-speech usage in
/// src/assistant/speech.ts.
final class AssistantSpeech: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AssistantSpeech()

    private let synthesizer = AVSpeechSynthesizer()
    private var startHandler: (() -> Void)?
    private var doneHandler: (() -> Void)?
    private var voices: [AVSpeechSynthesisVoice] = []

    private override init() {
        super.init()
        synthesizer.delegate = self
        voices = AVSpeechSynthesisVoice.speechVoices()
    }

    func loadVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices()
    }

    /// Speaks the text, cancelling anything already being said.
    func speak(_ text: String, onStart: @escaping () -> Void, onDone: @escaping () -> Void) {
        stop()
        startHandler = onStart
        doneHandler = onDone

        let cleaned = AssistantSpeech.cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            finish()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Could not configure the audio session for speech.", error)
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = pickVoice(arabic: AssistantCopy.containsArabic(cleaned))
        utterance.rate = min(max(AVSpeechUtteranceDefaultSpeechRate * 1.03, 0.1), 1.0)
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finish()
    }

    private func finish() {
        guard let done = doneHandler else { return }
        startHandler = nil
        doneHandler = nil
        done()
    }

    private func pickVoice(arabic: Bool) -> AVSpeechSynthesisVoice? {
        let prefix = arabic ? "ar" : "en"
        let matching = voices.filter { $0.language.lowercased().hasPrefix(prefix) }
        let preferred = matching.first { voice in
            voice.name.range(
                of: "natural|aria|jenny|samantha|zira|female|google us english",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
        return preferred
            ?? matching.first { $0.language.lowercased() == "en-us" }
            ?? matching.first
            ?? AVSpeechSynthesisVoice(language: arabic ? "ar-SA" : "en-US")
    }

    /// Strips emoji so the voice doesn't read out their names.
    private static func cleanForSpeech(_ text: String) -> String {
        let filtered = text.unicodeScalars.filter { scalar in
            let value = scalar.value
            let emoji = (0x1F000...0x1FAFF).contains(value)
                || (0x2600...0x27BF).contains(value)
                || (0x2B00...0x2BFF).contains(value)
            return !emoji
        }
        let cleaned = filtered.reduce(into: "") { result, scalar in
            result.unicodeScalars.append(scalar)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let handler = startHandler
        DispatchQueue.main.async { handler?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.finish() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.finish() }
    }
}
