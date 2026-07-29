#if os(macOS)
import AudioToolbox
import AVFoundation
import Combine
import CoreAudio
import Foundation

final class AudioEngineController: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)

        var label: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting"
            case .running: return "Running"
            case .failed(let message): return message
            }
        }
    }

    private struct DetectionFocus {
        let minimumFrequency: Double
        let maximumFrequency: Double
        let expiresAt: TimeInterval
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var inputLevelDB: Double = -120
    @Published private(set) var latestPitch: DetectedPitch?
    @Published private(set) var sampleRate: Double = 48_000

    var onPitch: ((DetectedPitch) -> Void)?

    private let engine = AVAudioEngine()
    private let monitorMixer = AVAudioMixerNode()
    private let synthMixer = AVAudioMixerNode()
    private let toneMixer = AVAudioMixerNode()
    private let distortion = AVAudioUnitDistortion()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 3)
    private let reverb = AVAudioUnitReverb()
    private var players: [AVAudioPlayerNode] = (0..<6).map { _ in AVAudioPlayerNode() }
    private let generator = PluckedStringGenerator()
    private let analysisQueue = DispatchQueue(label: "StringPilot.PitchAnalysis", qos: .userInteractive)
    private var analysisBuffer: [Float] = []
    private var lastAnalysisTime: TimeInterval = 0
    private var pitchDetector = YINPitchDetector()
    private var detectionFocus: DetectionFocus?
    private var sensitivity: Double = 3
    private var noiseGateDB: Double = -58
    private var preferredInputDeviceID: AudioDeviceID?
    private var preferredOutputDeviceID: AudioDeviceID?
    private var nodesAttached = false
    private var configured = false
    private var seedCounter: UInt64 = 1
    private var tapInstalled = false

    func setPreferredDevices(inputID: AudioDeviceID, outputID: AudioDeviceID) {
        preferredInputDeviceID = inputID == 0 ? nil : inputID
        preferredOutputDeviceID = outputID == 0 ? nil : outputID
    }

    func selectDevices(inputID: AudioDeviceID, outputID: AudioDeviceID) {
        setPreferredDevices(inputID: inputID, outputID: outputID)
        restart()
    }

    func focusDetection(
        minimumFrequency: Double,
        maximumFrequency: Double,
        duration: TimeInterval = 0.24
    ) {
        let minimum = max(20, min(minimumFrequency, maximumFrequency))
        let maximum = max(minimum, max(minimumFrequency, maximumFrequency))
        let focus = DetectionFocus(
            minimumFrequency: minimum,
            maximumFrequency: maximum,
            expiresAt: ProcessInfo.processInfo.systemUptime + max(0.05, duration)
        )
        analysisQueue.async { [weak self] in
            self?.detectionFocus = focus
        }
    }

    func requestPermissionAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            start()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted { start() }
            else { state = .failed("Microphone/input permission was denied.") }
        case .denied, .restricted:
            state = .failed("Microphone/input permission is disabled in System Settings.")
        @unknown default:
            state = .failed("The audio-input permission state is unknown.")
        }
    }

    func start() {
        guard state != .running, state != .starting else { return }
        state = .starting
        do {
            if !configured { try configureGraph() }
            engine.prepare()
            try engine.start()
            state = .running
        } catch {
            state = .failed("Audio could not start: \(error.localizedDescription)")
        }
    }

    func stop() {
        players.forEach { $0.stop() }
        engine.stop()
        state = .stopped
    }

    func restart() {
        tearDownGraph()
        start()
    }

    func apply(settings: AppSettings) {
        sensitivity = max(0.5, min(20, settings.inputSensitivity))
        noiseGateDB = max(-90, min(-20, settings.noiseGateDB))
        monitorMixer.outputVolume = settings.monitorInput ? 1 : 0
        synthMixer.outputVolume = Float(max(0, min(1.5, settings.outputGain)))
        distortion.preGain = Float(max(-12, min(24, settings.drive)))
        distortion.wetDryMix = Float(max(0, min(100, settings.drive * 3.2)))
        reverb.wetDryMix = Float(max(0, min(65, settings.reverbMix)))
    }

    func play(stringIndex: Int, frequency: Double, velocity: Double, palmMute: Double) {
        guard players.indices.contains(stringIndex), state == .running else { return }
        let player = players[stringIndex]
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let duration = palmMute > 0.7 ? 0.22 : 1.1
        seedCounter &+= 0x9E3779B97F4A7C15
        let samples = generator.generate(.init(
            frequency: frequency,
            sampleRate: sampleRate,
            duration: duration,
            velocity: velocity,
            palmMute: palmMute,
            seed: seedCounter ^ UInt64(stringIndex + 1)
        ))
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ), let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: samples.count)
        }

        player.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !player.isPlaying { player.play() }
    }

    private func configureGraph() throws {
        let input = engine.inputNode
        let output = engine.outputNode
        try applyPreferredDevice(preferredInputDeviceID, to: input.audioUnit, role: "input")
        try applyPreferredDevice(preferredOutputDeviceID, to: output.audioUnit, role: "output")

        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioEngineError.noInput
        }
        sampleRate = inputFormat.sampleRate

        if !nodesAttached {
            [monitorMixer, synthMixer, toneMixer, distortion, equalizer, reverb].forEach(engine.attach)
            players.forEach(engine.attach)
            nodesAttached = true
        }

        engine.connect(input, to: monitorMixer, format: inputFormat)
        engine.connect(monitorMixer, to: toneMixer, format: nil)

        guard let synthFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw AudioEngineError.invalidFormat
        }
        for player in players {
            engine.connect(player, to: synthMixer, format: synthFormat)
        }
        engine.connect(synthMixer, to: toneMixer, format: nil)
        engine.connect(toneMixer, to: distortion, format: nil)
        engine.connect(distortion, to: equalizer, format: nil)
        engine.connect(equalizer, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        configureEQ()
        reverb.loadFactoryPreset(.mediumRoom)

        input.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] buffer, time in
            self?.copyForAnalysis(buffer: buffer, time: time)
        }
        tapInstalled = true
        configured = true
    }

    private func tearDownGraph() {
        players.forEach { $0.stop() }
        engine.stop()

        let input = engine.inputNode
        if tapInstalled {
            input.removeTap(onBus: 0)
            tapInstalled = false
        }

        engine.disconnectNodeOutput(input)
        players.forEach(engine.disconnectNodeOutput)
        [monitorMixer, synthMixer, toneMixer, distortion, equalizer, reverb].forEach(engine.disconnectNodeOutput)
        engine.reset()
        configured = false
        latestPitch = nil
        inputLevelDB = -120
        analysisQueue.sync {
            analysisBuffer.removeAll(keepingCapacity: true)
            lastAnalysisTime = 0
            detectionFocus = nil
        }
    }

    private func applyPreferredDevice(
        _ deviceID: AudioDeviceID?,
        to audioUnit: AudioUnit?,
        role: String
    ) throws {
        guard let deviceID else { return }
        guard let audioUnit else { throw AudioEngineError.missingAudioUnit(role) }
        var mutableID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.deviceSelection(role: role, status: status)
        }
    }

    private func configureEQ() {
        let bands = equalizer.bands
        guard bands.count >= 3 else { return }
        bands[0].filterType = .highPass
        bands[0].frequency = 34
        bands[0].bandwidth = 0.5
        bands[0].bypass = false

        bands[1].filterType = .parametric
        bands[1].frequency = 1_600
        bands[1].bandwidth = 1.0
        bands[1].gain = 1.5
        bands[1].bypass = false

        bands[2].filterType = .lowPass
        bands[2].frequency = 13_500
        bands[2].bandwidth = 0.5
        bands[2].bypass = false
    }

    private func copyForAnalysis(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return }

        var mono = Array(repeating: Float.zero, count: frameCount)
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frame in 0..<frameCount {
                mono[frame] += channel[frame] / Float(channelCount)
            }
        }
        let rate = buffer.format.sampleRate
        let timestamp = time.hostTime == 0 ? ProcessInfo.processInfo.systemUptime : AVAudioTime.seconds(forHostTime: time.hostTime)

        let gain = sensitivity
        let gate = noiseGateDB
        analysisQueue.async { [weak self] in
            self?.consume(samples: mono, sampleRate: rate, timestamp: timestamp, gain: gain, gateDB: gate)
        }
    }

    private func consume(
        samples: [Float],
        sampleRate: Double,
        timestamp: TimeInterval,
        gain: Double,
        gateDB: Double
    ) {
        let amplified = samples.map { Float(Double($0) * gain) }
        analysisBuffer.append(contentsOf: amplified)
        let maximumFrames = 8_192
        if analysisBuffer.count > maximumFrames {
            analysisBuffer.removeFirst(analysisBuffer.count - maximumFrames)
        }

        let rms = sqrt(amplified.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, amplified.count)))
        let db = 20 * log10(max(1e-8, rms))
        DispatchQueue.main.async { [weak self] in self?.inputLevelDB = db }

        let now = ProcessInfo.processInfo.systemUptime
        if let focus = detectionFocus, now > focus.expiresAt {
            detectionFocus = nil
        }
        let focus = detectionFocus
        let analysisInterval = focus == nil ? 0.025 : 0.012
        guard timestamp - lastAnalysisTime >= analysisInterval else { return }

        let frameRequirement: Int
        if let focus {
            let cycles = 3.5
            frameRequirement = max(
                1_024,
                min(maximumFrames, Int(ceil(sampleRate / focus.minimumFrequency * cycles)))
            )
        } else {
            frameRequirement = 4_096
        }
        guard analysisBuffer.count >= frameRequirement else { return }
        lastAnalysisTime = timestamp

        var detector = pitchDetector
        detector.minimumRMS = pow(10, gateDB / 20)
        if let focus {
            detector.minimumFrequency = max(20, focus.minimumFrequency * 0.85)
            detector.maximumFrequency = min(2_200, focus.maximumFrequency * 1.12)
        }
        guard let pitch = detector.detect(
            samples: Array(analysisBuffer.suffix(frameRequirement)),
            sampleRate: sampleRate,
            timestamp: timestamp
        ) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.latestPitch = pitch
            self?.onPitch?(pitch)
        }
    }
}

enum AudioEngineError: LocalizedError {
    case noInput
    case invalidFormat
    case missingAudioUnit(String)
    case deviceSelection(role: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .noInput:
            return "No usable audio input is selected. Connect the iRig and choose it as the input device."
        case .invalidFormat:
            return "The selected audio device did not provide a usable mono playback format."
        case .missingAudioUnit(let role):
            return "The macOS \(role) audio unit is unavailable."
        case .deviceSelection(let role, let status):
            return "The selected \(role) device could not be opened. Core Audio error \(status)."
        }
    }
}
#endif
