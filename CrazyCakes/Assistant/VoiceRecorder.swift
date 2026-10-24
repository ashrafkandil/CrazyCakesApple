import AVFoundation
import Combine
import Foundation

struct VoiceClip {
    let mimeType: String
    let data: String
}

/// Records the visitor's voice into a compact mono m4a clip for Gemini - the native
/// twin of src/assistant/voiceRecorder.ts (expo-audio).
@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var level: Double = 0
    @Published private(set) var seconds = 0
    @Published private(set) var hearingVoice = false
    @Published private(set) var busy = false

    var onClip: ((VoiceClip) -> Void)?
    var onError: ((VoiceError) -> Void)?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var heardVoice = false
    private var finishing = false

    private let maxDuration: TimeInterval = 20
    private let minSpeech: TimeInterval = 0.4
    private let tickInterval: TimeInterval = 0.12

    func start() {
        guard recorder?.isRecording != true else { return }
        busy = true
        requestPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.busy = false
                    let denied = AVAudioSession.sharedInstance().recordPermission == .denied
                    self.onError?(denied ? .denied : .noMic)
                    return
                }
                self.beginRecording()
            }
        }
    }

    func stop() {
        finish(send: true)
    }

    func cancel() {
        finish(send: false)
    }

    private func requestPermission(_ completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in completion(granted) }
        @unknown default:
            completion(false)
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32000,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record()

            self.recorder = recorder
            startedAt = Date()
            heardVoice = false
            hearingVoice = false
            level = 0
            seconds = 0
            recording = true
            busy = false
            startMetering()
        } catch {
            busy = false
            recording = false
            onError?(.failed)
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let decibels = Double(recorder.averagePower(forChannel: 0))
        let normalized = max(0, min(1, (decibels + 60) / 40))
        level = normalized
        if normalized > 0.2 {
            heardVoice = true
            hearingVoice = true
        }
        guard let startedAt else { return }
        seconds = Int(Date().timeIntervalSince(startedAt))
        if Date().timeIntervalSince(startedAt) > maxDuration {
            finish(send: true)
        }
    }

    private func finish(send: Bool) {
        guard !finishing else { return }
        finishing = true
        defer { finishing = false }

        meterTimer?.invalidate()
        meterTimer = nil

        guard let recorder else { return }
        let url = recorder.url
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        recorder.stop()
        self.recorder = nil
        startedAt = nil
        recording = false
        level = 0
        hearingVoice = false
        seconds = 0

        // Hand the session back to playback so replies are audible.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        guard send else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard elapsed >= minSpeech || heardVoice else {
            try? FileManager.default.removeItem(at: url)
            onError?(.noSpeech)
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            onError?(.failed)
            return
        }
        try? FileManager.default.removeItem(at: url)
        onClip?(VoiceClip(mimeType: "audio/m4a", data: data.base64EncodedString()))
    }
}
