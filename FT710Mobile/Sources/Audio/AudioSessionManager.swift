import AVFoundation

extension Notification.Name {
    /// Posted after a route change or a resumable interruption ends — RX/TX
    /// engines observe this and restart themselves against the new hardware.
    static let audioSessionNeedsEngineRestart = Notification.Name("audioSessionNeedsEngineRestart")
}

/// Unified audio session manager for FT710 mobile app.
/// Handles .playAndRecord mode to avoid interruptions during TX/RX switching.
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    @Published var isActive: Bool = false
    @Published var isBluetoothConnected: Bool = false

    private let session = AVAudioSession.sharedInstance()
    private var isObserving = false

    private init() {}

    /// Configure audio session for both TX and RX.
    func configureForTransceiver() throws {
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                               options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        // Best-effort: MFi/BLE hearing aids reject buffer durations this short and
        // throw here, which used to abort the whole function before setActive(true)
        // ran — silently blocking audio (to ANY route) whenever a hearing aid was paired.
        try? session.setPreferredIOBufferDuration(0.005)  // 5ms for low latency
        try session.setActive(true)
        isActive = true
        startObserving()
        print("✅ Audio session configured for transceiver mode")
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange),
                                                name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
                                                name: AVAudioSession.interruptionNotification, object: session)
    }

    /// Route changed (e.g. speaker ↔ hearing aid/Bluetooth). Reactivating here
    /// is what actually applies the new route — without it iOS can leave the
    /// session pointed at the old hardware even after the picker selection.
    @objc private func handleRouteChange(notification: Notification) {
        print("🔄 Audio route changed")
        try? session.setActive(true)
        NotificationCenter.default.post(name: .audioSessionNeedsEngineRestart, object: nil)
    }

    /// A Bluetooth/hearing-aid connect or disconnect is reported as an audio
    /// interruption, not just a route change. On `.ended` with `.shouldResume`,
    /// the session must be reactivated and the engines restarted, or audio
    /// stays dead even after the user manually switches back to the speaker.
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        guard type == .ended else { return }
        let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        guard options.contains(.shouldResume) else { return }
        print("🔄 Audio interruption ended — resuming")
        try? session.setActive(true)
        NotificationCenter.default.post(name: .audioSessionNeedsEngineRestart, object: nil)
    }

    /// Check if Bluetooth is currently connected
    func isBluetoothActive() -> Bool {
        return session.currentRoute.outputs.contains { $0.portType == .bluetoothHFP ||
                                                       $0.portType == .bluetoothA2DP }
    }
}
