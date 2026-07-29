#if os(macOS)
import CoreMIDI
import Foundation

struct MIDIDestination: Identifiable, Hashable {
    let id: MIDIUniqueID
    let endpoint: MIDIEndpointRef
    let name: String
}

@MainActor
final class MIDIOutput: ObservableObject {
    @Published private(set) var destinations: [MIDIDestination] = []
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDestinationID: MIDIUniqueID?

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var virtualSource = MIDIEndpointRef()

    init() {
        configure()
    }

    deinit {
        if virtualSource != 0 { MIDIEndpointDispose(virtualSource) }
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    func refreshDestinations() {
        var found: [MIDIDestination] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { continue }
            var uniqueID = MIDIUniqueID(0)
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
            let name = Self.endpointName(endpoint) ?? "MIDI destination \(index + 1)"
            found.append(MIDIDestination(id: uniqueID, endpoint: endpoint, name: name))
        }
        destinations = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let selectedDestinationID, !destinations.contains(where: { $0.id == selectedDestinationID }) {
            self.selectedDestinationID = nil
        }
    }

    func noteOn(note: Int, velocity: Int, channel: Int) {
        let message = MIDI1UPNoteOn(0, UInt8(clamping: channel), UInt8(clamping: note), UInt8(clamping: velocity))
        send(message)
    }

    func noteOff(note: Int, velocity: Int = 0, channel: Int) {
        let message = MIDI1UPNoteOff(0, UInt8(clamping: channel), UInt8(clamping: note), UInt8(clamping: velocity))
        send(message)
    }

    func pitchBend(cents: Double, rangeSemitones: Double = 2, channel: Int) {
        let normalized = max(-1, min(1, cents / (rangeSemitones * 100)))
        let value = Int(round(8192 + normalized * 8191))
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        send(MIDI1UPPitchBend(0, UInt8(clamping: channel), lsb, msb))
    }

    func allNotesOff() {
        for channel in 0..<16 {
            send(MIDI1UPControlChange(0, UInt8(channel), 123, 0))
        }
    }

    private func configure() {
        var status = MIDIClientCreateWithBlock("StringPilot" as CFString, &client) { [weak self] _ in
            Task { @MainActor in self?.refreshDestinations() }
        }
        guard status == noErr else { return fail("Could not create the CoreMIDI client.", status) }

        status = MIDIOutputPortCreate(client, "StringPilot Output" as CFString, &outputPort)
        guard status == noErr else { return fail("Could not create the MIDI output port.", status) }

        status = MIDISourceCreateWithProtocol(client, "StringPilot" as CFString, ._1_0, &virtualSource)
        guard status == noErr else { return fail("Could not create the StringPilot virtual MIDI source.", status) }

        let stableID = MIDIUniqueID(0x5350_0001)
        MIDIObjectSetIntegerProperty(virtualSource, kMIDIPropertyUniqueID, stableID)
        isAvailable = true
        errorMessage = nil
        refreshDestinations()
    }

    private func fail(_ message: String, _ status: OSStatus) {
        isAvailable = false
        errorMessage = "\(message) CoreMIDI error \(status)."
    }

    private func send(_ message: MIDIMessage_32) {
        guard isAvailable else { return }
        var eventList = MIDIEventList()
        var mutableMessage = message
        let packet = MIDIEventListInit(&eventList, ._1_0)
        withUnsafePointer(to: &mutableMessage) { pointer in
            _ = MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, pointer)
        }
        _ = MIDIReceivedEventList(virtualSource, &eventList)

        if let selectedDestinationID,
           let destination = destinations.first(where: { $0.id == selectedDestinationID }) {
            _ = MIDISendEventList(outputPort, destination.endpoint, &eventList)
        }
    }

    private static func endpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var unmanaged: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanaged) == noErr,
              let value = unmanaged?.takeRetainedValue() else { return nil }
        return value as String
    }
}
#endif
