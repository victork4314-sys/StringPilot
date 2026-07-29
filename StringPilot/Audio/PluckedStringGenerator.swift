import Foundation

struct PluckedStringGenerator {
    struct Parameters {
        var frequency: Double
        var sampleRate: Double
        var duration: Double
        var velocity: Double
        var palmMute: Double
        var seed: UInt64
    }

    func generate(_ parameters: Parameters) -> [Float] {
        let frequency = max(20, parameters.frequency)
        let sampleRate = max(8_000, parameters.sampleRate)
        let frameCount = max(64, Int(parameters.duration * sampleRate))
        let delayLength = max(2, Int(sampleRate / frequency))
        let damping = 0.9992 - min(1, max(0, parameters.palmMute)) * 0.025
        let brightness = 0.42 + min(1, max(0, parameters.velocity)) * 0.42

        var rng = SplitMix64(seed: parameters.seed)
        var delay = Array(repeating: 0.0, count: delayLength)
        for i in delay.indices {
            let noise = rng.nextUnit() * 2.0 - 1.0
            delay[i] = noise * brightness
        }

        var output = Array(repeating: Float.zero, count: frameCount)
        var cursor = 0
        var previous = 0.0

        for frame in 0..<frameCount {
            let current = delay[cursor]
            let next = delay[(cursor + 1) % delayLength]
            let averaged = (current + next) * 0.5 * damping
            delay[cursor] = averaged
            cursor = (cursor + 1) % delayLength

            let highPassed = current - previous * 0.96
            previous = current
            let envelope = min(1.0, Double(frame) / 24.0) * exp(-Double(frame) / (sampleRate * (0.7 - parameters.palmMute * 0.48)))
            output[frame] = Float(highPassed * envelope * max(0.05, parameters.velocity))
        }

        return output
    }
}

struct CapturedAttack: Equatable {
    let samples: [Float]
    let sampleRate: Double
    let sourceFrequency: Double
}

struct CapturedAttackProcessor {
    func prepare(
        samples: [Float],
        sampleRate: Double,
        sourceFrequency: Double
    ) -> CapturedAttack? {
        guard samples.count >= 256,
              sampleRate.isFinite,
              sampleRate >= 8_000,
              sourceFrequency.isFinite,
              sourceFrequency >= 20,
              samples.allSatisfy(\.isFinite) else { return nil }

        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        var highPassed = Array(repeating: Float.zero, count: samples.count)
        var previousInput = 0.0
        var previousOutput = 0.0
        for index in samples.indices {
            let input = Double(samples[index]) - mean
            let output = input - previousInput + 0.995 * previousOutput
            highPassed[index] = Float(output)
            previousInput = input
            previousOutput = output
        }

        let rms = sqrt(highPassed.reduce(0.0) { $0 + Double($1 * $1) } / Double(highPassed.count))
        let peak = highPassed.reduce(0.0) { max($0, abs(Double($1))) }
        guard rms >= 0.000_01, peak >= 0.000_1 else { return nil }

        let onsetThreshold = max(peak * 0.08, rms * 1.35)
        guard let onset = highPassed.firstIndex(where: { abs(Double($0)) >= onsetThreshold }) else { return nil }
        let preRollFrames = max(1, Int(sampleRate * 0.0015))
        let start = max(0, onset - preRollFrames)
        let maximumLength = max(256, Int(sampleRate * 0.28))
        let end = min(highPassed.count, start + maximumLength)
        guard end - start >= 256 else { return nil }

        var segment = Array(highPassed[start..<end])
        let segmentPeak = segment.reduce(0.0) { max($0, abs(Double($1))) }
        guard segmentPeak > 0 else { return nil }
        let normalization = min(24.0, 0.9 / segmentPeak)
        let fadeInFrames = max(1, Int(sampleRate * 0.0015))
        let fadeOutFrames = max(1, min(segment.count / 4, Int(sampleRate * 0.008)))

        for index in segment.indices {
            var gain = normalization
            if index < fadeInFrames {
                gain *= Double(index + 1) / Double(fadeInFrames)
            }
            let framesFromEnd = segment.count - 1 - index
            if framesFromEnd < fadeOutFrames {
                gain *= Double(framesFromEnd) / Double(fadeOutFrames)
            }
            segment[index] = Float(Double(segment[index]) * gain)
        }

        return CapturedAttack(
            samples: segment,
            sampleRate: sampleRate,
            sourceFrequency: sourceFrequency
        )
    }

    func render(
        _ attack: CapturedAttack,
        targetSampleRate: Double,
        targetFrequency: Double,
        frameCount: Int,
        velocity: Double,
        seed: UInt64
    ) -> [Float] {
        guard frameCount > 0,
              attack.samples.count >= 2,
              targetSampleRate >= 8_000,
              targetFrequency >= 20 else {
            return Array(repeating: 0, count: max(0, frameCount))
        }

        let pitchRatio = targetFrequency / attack.sourceFrequency
        let sampleRateRatio = attack.sampleRate / targetSampleRate
        let sourceStep = max(0.05, pitchRatio * sampleRateRatio)
        let jitterLimit = min(6, max(0, attack.samples.count - 2))
        let jitter = jitterLimit == 0 ? 0 : Int(seed % UInt64(jitterLimit + 1))
        let variation = 0.96 + Double((seed >> 8) % 9) * 0.01
        let level = max(0.05, min(1, velocity)) * variation
        var output = Array(repeating: Float.zero, count: frameCount)

        for frame in output.indices {
            let sourcePosition = Double(jitter) + Double(frame) * sourceStep
            let lower = Int(sourcePosition)
            guard lower + 1 < attack.samples.count else { break }
            let fraction = sourcePosition - Double(lower)
            let first = Double(attack.samples[lower])
            let second = Double(attack.samples[lower + 1])
            output[frame] = Float((first + (second - first) * fraction) * level)
        }
        return output
    }

    func blend(model: [Float], captured: [Float]) -> [Float] {
        guard !captured.isEmpty else { return model }
        var output = model
        let count = min(output.count, captured.count)
        for index in 0..<count {
            let mixed = Double(output[index]) * 0.62 + Double(captured[index]) * 0.82
            output[index] = Float(mixed / (1 + abs(mixed) * 0.32))
        }
        return output
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
