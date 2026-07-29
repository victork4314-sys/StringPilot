#if os(macOS)
import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let hasInput: Bool
    let hasOutput: Bool
}

@MainActor
final class AudioDeviceManager: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultInputID: AudioDeviceID = 0
    @Published private(set) var defaultOutputID: AudioDeviceID = 0
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    var inputDevices: [AudioDevice] { devices.filter(\.hasInput) }
    var outputDevices: [AudioDevice] { devices.filter(\.hasOutput) }

    func refresh() {
        do {
            devices = try Self.readDevices()
            defaultInputID = try Self.readDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
            defaultOutputID = try Self.readDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefaultInput(_ id: AudioDeviceID) throws {
        try Self.setDefaultDevice(id, selector: kAudioHardwarePropertyDefaultInputDevice)
        defaultInputID = id
    }

    func setDefaultOutput(_ id: AudioDeviceID) throws {
        try Self.setDefaultDevice(id, selector: kAudioHardwarePropertyDefaultOutputDevice)
        defaultOutputID = id
    }

    private static func readDevices() throws -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = Array(repeating: AudioDeviceID(0), count: count)
        try ids.withUnsafeMutableBytes { bytes in
            var mutableSize = size
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &mutableSize, bytes.baseAddress!))
        }

        return ids.compactMap { id in
            let input = hasStreams(deviceID: id, scope: kAudioDevicePropertyScopeInput)
            let output = hasStreams(deviceID: id, scope: kAudioDevicePropertyScopeOutput)
            guard input || output else { return nil }
            return AudioDevice(
                id: id,
                name: stringProperty(deviceID: id, selector: kAudioObjectPropertyName) ?? "Audio device \(id)",
                uid: stringProperty(deviceID: id, selector: kAudioDevicePropertyDeviceUID) ?? String(id),
                hasInput: input,
                hasOutput: output
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func stringProperty(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0)
        }
        return status == noErr ? value as String : nil
    }

    private static func readDefaultDevice(selector: AudioObjectPropertySelector) throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value))
        return value
    }

    private static func setDefaultDevice(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &value))
    }

    private static func check(_ status: OSStatus) throws {
        guard status == noErr else { throw AudioDeviceError.osStatus(status) }
    }
}

enum AudioDeviceError: LocalizedError {
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            return "Core Audio returned error \(status)."
        }
    }
}
#endif
