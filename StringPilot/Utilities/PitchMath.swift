import Foundation

enum PitchMath {
    static func frequency(forMIDINote note: Double) -> Double {
        440.0 * pow(2.0, (note - 69.0) / 12.0)
    }

    static func midiNote(forFrequency frequency: Double) -> Double {
        guard frequency > 0 else { return 0 }
        return 69.0 + 12.0 * log2(frequency / 440.0)
    }

    static func centsBetween(_ frequency: Double, and reference: Double) -> Double {
        guard frequency > 0, reference > 0 else { return 0 }
        return 1200.0 * log2(frequency / reference)
    }

    static func noteName(forMIDINote note: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let safe = ((note % 12) + 12) % 12
        let octave = note / 12 - 1
        return "\(names[safe])\(octave)"
    }
}
