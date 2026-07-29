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
