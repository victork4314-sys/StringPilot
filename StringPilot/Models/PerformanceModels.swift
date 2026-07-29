import Foundation

enum PerformanceMode: String, CaseIterable, Codable, Identifiable {
    case single = "Single"
    case tremolo = "Tremolo"
    case strum = "Strum"
    case pattern = "Pattern"

    var id: String { rawValue }
}

enum NoteSubdivision: String, CaseIterable, Codable, Identifiable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    var id: String { rawValue }

    var eventsPerBeat: Double {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .sixteenth: return 4
        case .thirtySecond: return 8
        }
    }

    func intervalSeconds(bpm: Double) -> Double {
        60.0 / max(1.0, bpm) / eventsPerBeat
    }
}

enum XboxInput: String, CaseIterable, Codable, Identifiable {
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    case leftShoulder = "LB"
    case rightShoulder = "RB"

    var id: String { rawValue }
}

struct InstrumentString: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let openMIDINote: Int
    let maximumFret: Int

    var openFrequency: Double {
        PitchMath.frequency(forMIDINote: Double(openMIDINote))
    }
}

struct InstrumentProfile: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let strings: [InstrumentString]

    static let guitarStandard = InstrumentProfile(
        id: "guitar-standard",
        name: "6-string guitar — standard",
        strings: [
            .init(id: 0, name: "1 · high E", openMIDINote: 64, maximumFret: 24),
            .init(id: 1, name: "2 · B", openMIDINote: 59, maximumFret: 24),
            .init(id: 2, name: "3 · G", openMIDINote: 55, maximumFret: 24),
            .init(id: 3, name: "4 · D", openMIDINote: 50, maximumFret: 24),
            .init(id: 4, name: "5 · A", openMIDINote: 45, maximumFret: 24),
            .init(id: 5, name: "6 · low E", openMIDINote: 40, maximumFret: 24)
        ]
    )

    static let guitarDropD = InstrumentProfile(
        id: "guitar-drop-d",
        name: "6-string guitar — Drop D",
        strings: [
            .init(id: 0, name: "1 · high E", openMIDINote: 64, maximumFret: 24),
            .init(id: 1, name: "2 · B", openMIDINote: 59, maximumFret: 24),
            .init(id: 2, name: "3 · G", openMIDINote: 55, maximumFret: 24),
            .init(id: 3, name: "4 · D", openMIDINote: 50, maximumFret: 24),
            .init(id: 4, name: "5 · A", openMIDINote: 45, maximumFret: 24),
            .init(id: 5, name: "6 · low D", openMIDINote: 38, maximumFret: 24)
        ]
    )

    static let bassFourString = InstrumentProfile(
        id: "bass-four-standard",
        name: "4-string bass — standard",
        strings: [
            .init(id: 0, name: "1 · G", openMIDINote: 43, maximumFret: 24),
            .init(id: 1, name: "2 · D", openMIDINote: 38, maximumFret: 24),
            .init(id: 2, name: "3 · A", openMIDINote: 33, maximumFret: 24),
            .init(id: 3, name: "4 · E", openMIDINote: 28, maximumFret: 24)
        ]
    )

    static let bassFiveString = InstrumentProfile(
        id: "bass-five-standard",
        name: "5-string bass — standard",
        strings: [
            .init(id: 0, name: "1 · G", openMIDINote: 43, maximumFret: 24),
            .init(id: 1, name: "2 · D", openMIDINote: 38, maximumFret: 24),
            .init(id: 2, name: "3 · A", openMIDINote: 33, maximumFret: 24),
            .init(id: 3, name: "4 · E", openMIDINote: 28, maximumFret: 24),
            .init(id: 4, name: "5 · B", openMIDINote: 23, maximumFret: 24)
        ]
    )

    static let ukuleleStandard = InstrumentProfile(
        id: "ukulele-standard",
        name: "Ukulele — standard",
        strings: [
            .init(id: 0, name: "1 · A", openMIDINote: 69, maximumFret: 20),
            .init(id: 1, name: "2 · E", openMIDINote: 64, maximumFret: 20),
            .init(id: 2, name: "3 · C", openMIDINote: 60, maximumFret: 20),
            .init(id: 3, name: "4 · high G", openMIDINote: 67, maximumFret: 20)
        ]
    )

    static let mandolinStandard = InstrumentProfile(
        id: "mandolin-standard",
        name: "Mandolin — standard courses",
        strings: [
            .init(id: 0, name: "1 · E course", openMIDINote: 76, maximumFret: 24),
            .init(id: 1, name: "2 · A course", openMIDINote: 69, maximumFret: 24),
            .init(id: 2, name: "3 · D course", openMIDINote: 62, maximumFret: 24),
            .init(id: 3, name: "4 · G course", openMIDINote: 55, maximumFret: 24)
        ]
    )

    static let all: [InstrumentProfile] = [
        .guitarStandard,
        .guitarDropD,
        .bassFourString,
        .bassFiveString,
        .ukuleleStandard,
        .mandolinStandard
    ]
}

struct DetectedPitch: Equatable {
    let frequency: Double
    let confidence: Double
    let rms: Double
    let timestamp: TimeInterval
}

struct ResolvedStringPitch: Equatable {
    let stringIndex: Int
    let fret: Int
    let midiNote: Int
    let frequency: Double
    let centsOffset: Double
    let confidence: Double

    var noteName: String { PitchMath.noteName(forMIDINote: midiNote) }
}

struct StringState: Identifiable, Equatable {
    let id: Int
    var fret: Int
    var midiNote: Int
    var frequency: Double
    var centsOffset: Double
    var confidence: Double
    var lastUpdated: Date?
    var isHeld: Bool

    static func openState(for string: InstrumentString) -> StringState {
        StringState(
            id: string.id,
            fret: 0,
            midiNote: string.openMIDINote,
            frequency: string.openFrequency,
            centsOffset: 0,
            confidence: 0,
            lastUpdated: nil,
            isHeld: false
        )
    }
}

struct PatternStep: Identifiable, Codable, Equatable {
    let id: UUID
    var stringNumber: Int?
    var accent: Bool

    init(id: UUID = UUID(), stringNumber: Int?, accent: Bool = false) {
        self.id = id
        self.stringNumber = stringNumber
        self.accent = accent
    }
}

struct SavedPattern: Codable, Equatable {
    var name: String
    var steps: [PatternStep]
    var loops: Bool

    static let defaultPattern = SavedPattern(
        name: "Alternating strings",
        steps: [1, 2, 1, 2].map { PatternStep(stringNumber: $0) },
        loops: true
    )
}

struct AppSettings: Codable, Equatable {
    var bpm: Double = 120
    var subdivision: NoteSubdivision = .sixteenth
    var mode: PerformanceMode = .single
    var profileID: String = InstrumentProfile.guitarStandard.id
    var inputSensitivity: Double = 3.0
    var noiseGateDB: Double = -58
    var outputGain: Double = 0.8
    var monitorInput: Bool = true
    var sendMIDI: Bool = true
    var midiDestinationUniqueID: Int32? = nil
    var strumSpreadMilliseconds: Double = 24
    var palmMute: Double = 0
    var reverbMix: Double = 8
    var drive: Double = 0
    var pattern: SavedPattern = .defaultPattern

    static let defaultsKey = "StringPilot.AppSettings.v1"
}
