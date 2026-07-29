import Foundation

struct StringPitchResolver {
    var maximumAcceptedCents: Double = 95

    func resolve(_ pitch: DetectedPitch, for string: InstrumentString) -> ResolvedStringPitch? {
        guard pitch.frequency > 0 else { return nil }

        var best: (fret: Int, midi: Int, frequency: Double, cents: Double)?

        for octaveShift in -2...2 {
            let shiftedFrequency = pitch.frequency * pow(2.0, Double(octaveShift))
            for fret in 0...string.maximumFret {
                let midi = string.openMIDINote + fret
                let targetFrequency = PitchMath.frequency(forMIDINote: Double(midi))
                let cents = PitchMath.centsBetween(shiftedFrequency, and: targetFrequency)
                if best == nil || abs(cents) < abs(best!.cents) {
                    best = (fret, midi, targetFrequency, cents)
                }
            }
        }

        guard let best, abs(best.cents) <= maximumAcceptedCents else { return nil }
        return ResolvedStringPitch(
            stringIndex: string.id,
            fret: best.fret,
            midiNote: best.midi,
            frequency: best.frequency * pow(2.0, best.cents / 1200.0),
            centsOffset: best.cents,
            confidence: pitch.confidence
        )
    }
}
