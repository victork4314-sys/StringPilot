#if os(macOS)
import Combine
import CoreAudio
import CoreMIDI
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var stringStates: [StringState] = []
    @Published private(set) var latestPitch: DetectedPitch?
    @Published private(set) var isPatternPlaying = false
    @Published private(set) var patternStepIndex = 0
    @Published var bannerMessage: String?

    let settingsStore = SettingsStore()
    let audio = AudioEngineController()
    let controller = XboxControllerManager()
    let midi = MIDIOutput()
    let devices = AudioDeviceManager()

    private let resolver = StringPitchResolver()
    private let repeatScheduler = RepeatScheduler()
    private var cancellables: Set<AnyCancellable> = []
    private var heldStrings: Set<Int> = []
    private var captureStringIndex: Int?
    private var captureWindowEnds = Date.distantPast
    private var activeMIDINotes: [Int: Int] = [:]
    private var lastSendMIDIEnabled: Bool

    var settings: AppSettings { settingsStore.settings }

    var profile: InstrumentProfile {
        InstrumentProfile.all.first(where: { $0.id == settings.profileID }) ?? .guitarStandard
    }

    static let directButtons: [XboxInput] = [.a, .b, .x, .y, .leftShoulder, .rightShoulder]

    init() {
        lastSendMIDIEnabled = settingsStore.settings.sendMIDI
        resetStringStates()
        wireServices()
        settingsStore.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                if self.lastSendMIDIEnabled && !settings.sendMIDI {
                    self.stopActiveMIDINotes()
                }
                self.lastSendMIDIEnabled = settings.sendMIDI
                self.audio.apply(settings: settings)
                self.midi.selectedDestinationID = settings.midiDestinationUniqueID
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func start() {
        audio.apply(settings: settings)
        Task { await audio.requestPermissionAndStart() }
    }

    func stop() {
        stopPattern()
        releaseHeldStrings()
        stopActiveMIDINotes()
        audio.stop()
    }

    func selectProfile(id: String) {
        guard InstrumentProfile.all.contains(where: { $0.id == id }) else { return }
        stopPattern()
        releaseHeldStrings()
        stopActiveMIDINotes()
        settingsStore.settings.profileID = id
        resetStringStates()
    }

    func setMode(_ mode: PerformanceMode) {
        if mode != .tremolo {
            for index in heldStrings { repeatScheduler.stop(id: index) }
        }
        if mode != .pattern { stopPattern() }
        settingsStore.settings.mode = mode
        if mode == .tremolo {
            heldStrings.forEach { startTremolo(stringIndex: $0) }
        }
    }

    func cycleMode(_ direction: Int) {
        let all = PerformanceMode.allCases
        guard let current = all.firstIndex(of: settings.mode) else { return }
        let next = (current + direction + all.count) % all.count
        setMode(all[next])
    }

    func adjustTempo(_ amount: Double) {
        settingsStore.settings.bpm = max(30, min(300, settings.bpm + amount))
        if settings.mode == .tremolo {
            heldStrings.forEach { startTremolo(stringIndex: $0) }
        }
        if isPatternPlaying {
            stopPattern()
            startPattern()
        }
    }

    func handleStringButton(index: Int, pressed: Bool) {
        guard profile.strings.indices.contains(index) else { return }
        if pressed {
            heldStrings.insert(index)
            stringStates[index].isHeld = true
            captureStringIndex = index
            captureWindowEnds = Date().addingTimeInterval(0.22)
            resolveLatestPitch(for: index)

            if settings.mode == .tremolo {
                startTremolo(stringIndex: index)
            } else {
                trigger(stringIndex: index)
            }
        } else {
            heldStrings.remove(index)
            stringStates[index].isHeld = false
            repeatScheduler.stop(id: index)
            if captureStringIndex == index { captureStringIndex = nil }
        }
    }

    func strum(upstroke: Bool) {
        guard settings.mode == .strum else { return }
        let indexes = upstroke ? Array(profile.strings.indices) : Array(profile.strings.indices.reversed())
        let spread = max(0, settings.strumSpreadMilliseconds) / 1_000
        for (offset, index) in indexes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + spread * Double(offset)) { [weak self] in
                self?.trigger(stringIndex: index)
            }
        }
    }

    func testPick(index: Int) {
        handleStringButton(index: index, pressed: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.handleStringButton(index: index, pressed: false)
        }
    }

    func togglePattern() {
        isPatternPlaying ? stopPattern() : startPattern()
    }

    func startPattern() {
        let steps = settings.pattern.steps
        guard !steps.isEmpty else {
            bannerMessage = "The pattern is empty."
            return
        }
        isPatternPlaying = true
        patternStepIndex = 0
        let interval = settings.subdivision.intervalSeconds(bpm: settings.bpm)
        repeatScheduler.start(id: 10_000, interval: interval) { [weak self] in
            Task { @MainActor in self?.advancePattern() }
        }
    }

    func stopPattern() {
        repeatScheduler.stop(id: 10_000)
        if isPatternPlaying {
            stopActiveMIDINotes()
        }
        isPatternPlaying = false
        patternStepIndex = 0
    }

    func applyPatternText(_ text: String) throws {
        let steps = try PatternParser().parse(text, maximumString: profile.strings.count)
        settingsStore.settings.pattern.steps = steps
    }

    func selectMIDIDestination(_ id: MIDIUniqueID?) {
        stopActiveMIDINotes()
        midi.selectedDestinationID = id
        settingsStore.settings.midiDestinationUniqueID = id
    }

    func chooseInputDevice(_ id: AudioDeviceID) {
        do {
            try devices.setDefaultInput(id)
            devices.refresh()
            audio.restart()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    func chooseOutputDevice(_ id: AudioDeviceID) {
        do {
            try devices.setDefaultOutput(id)
            devices.refresh()
            audio.restart()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    private func wireServices() {
        audio.onPitch = { [weak self] pitch in self?.handlePitch(pitch) }
        controller.onStringButton = { [weak self] index, pressed in self?.handleStringButton(index: index, pressed: pressed) }
        controller.onModeCycle = { [weak self] direction in self?.cycleMode(direction) }
        controller.onTempoChange = { [weak self] amount in self?.adjustTempo(amount) }
        controller.onStrum = { [weak self] upstroke in self?.strum(upstroke: upstroke) }
        controller.onPatternToggle = { [weak self] in self?.togglePattern() }
    }

    private func resetStringStates() {
        stringStates = profile.strings.map(StringState.openState)
    }

    private func releaseHeldStrings() {
        repeatScheduler.stopAll()
        heldStrings.removeAll()
        captureStringIndex = nil
        captureWindowEnds = .distantPast
        for index in stringStates.indices {
            stringStates[index].isHeld = false
        }
    }

    private func stopActiveMIDINotes() {
        midi.allNotesOff()
        activeMIDINotes.removeAll()
    }

    private func handlePitch(_ pitch: DetectedPitch) {
        latestPitch = pitch
        guard pitch.confidence >= 0.55 else { return }

        let target: Int?
        if let captureStringIndex, Date() <= captureWindowEnds {
            target = captureStringIndex
        } else if heldStrings.count == 1 {
            target = heldStrings.first
        } else {
            target = nil
        }
        guard let target else { return }
        apply(pitch: pitch, to: target)
    }

    private func resolveLatestPitch(for index: Int) {
        guard let latestPitch, ProcessInfo.processInfo.systemUptime - latestPitch.timestamp < 0.35 else { return }
        apply(pitch: latestPitch, to: index)
    }

    private func apply(pitch: DetectedPitch, to index: Int) {
        guard profile.strings.indices.contains(index),
              let resolved = resolver.resolve(pitch, for: profile.strings[index]) else { return }
        stringStates[index].fret = resolved.fret
        stringStates[index].midiNote = resolved.midiNote
        stringStates[index].frequency = resolved.frequency
        stringStates[index].centsOffset = resolved.centsOffset
        stringStates[index].confidence = resolved.confidence
        stringStates[index].lastUpdated = Date()

        if settings.sendMIDI, activeMIDINotes[index] != nil {
            midi.pitchBend(cents: resolved.centsOffset, channel: index)
        }
    }

    private func startTremolo(stringIndex: Int) {
        let interval = settings.subdivision.intervalSeconds(bpm: settings.bpm)
        repeatScheduler.start(id: stringIndex, interval: interval) { [weak self] in
            Task { @MainActor in self?.trigger(stringIndex: stringIndex) }
        }
    }

    private func trigger(stringIndex: Int, accent: Bool = false) {
        guard stringStates.indices.contains(stringIndex) else { return }
        let state = stringStates[stringIndex]
        let triggerPressure = Double(controller.rightTriggerValue)
        let baseVelocity = 0.52 + triggerPressure * 0.43
        let velocity = min(1, baseVelocity + (accent ? 0.18 : 0))
        audio.play(
            stringIndex: stringIndex,
            frequency: state.frequency,
            velocity: velocity,
            palmMute: settings.palmMute
        )

        guard settings.sendMIDI else { return }
        if let old = activeMIDINotes[stringIndex] {
            midi.noteOff(note: old, channel: stringIndex)
            midi.resetPitchBend(channel: stringIndex)
        }
        activeMIDINotes[stringIndex] = state.midiNote
        midi.pitchBend(cents: state.centsOffset, channel: stringIndex)
        midi.noteOn(note: state.midiNote, velocity: Int(velocity * 127), channel: stringIndex)

        let gate = min(0.24, settings.subdivision.intervalSeconds(bpm: settings.bpm) * 0.78)
        DispatchQueue.main.asyncAfter(deadline: .now() + gate) { [weak self] in
            guard let self, self.activeMIDINotes[stringIndex] == state.midiNote else { return }
            self.midi.noteOff(note: state.midiNote, channel: stringIndex)
            self.midi.resetPitchBend(channel: stringIndex)
            self.activeMIDINotes.removeValue(forKey: stringIndex)
        }
    }

    private func advancePattern() {
        let steps = settings.pattern.steps
        guard !steps.isEmpty else { return stopPattern() }
        if patternStepIndex >= steps.count {
            if settings.pattern.loops { patternStepIndex = 0 }
            else { return stopPattern() }
        }
        let step = steps[patternStepIndex]
        patternStepIndex += 1
        if let number = step.stringNumber, profile.strings.indices.contains(number - 1) {
            trigger(stringIndex: number - 1, accent: step.accent)
        }
    }
}
#endif
