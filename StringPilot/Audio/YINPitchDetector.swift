import Foundation

struct YINPitchDetector {
    var threshold: Double = 0.15
    var minimumFrequency: Double = 25
    var maximumFrequency: Double = 1600
    var minimumRMS: Double = 0.0007

    func detect(samples input: [Float], sampleRate: Double, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DetectedPitch? {
        guard input.count >= 256, sampleRate > 0 else { return nil }

        let mean = input.reduce(0.0) { $0 + Double($1) } / Double(input.count)
        var samples = [Double]()
        samples.reserveCapacity(input.count / 2)

        // Downsample by two with a two-sample moving average. This lowers CPU cost
        // while retaining the full guitar, bass, mandolin, and ukulele range.
        var index = 0
        while index + 1 < input.count {
            let value = (Double(input[index]) + Double(input[index + 1])) * 0.5 - mean
            samples.append(value)
            index += 2
        }

        let effectiveRate = sampleRate * 0.5
        let rms = sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count))
        guard rms >= minimumRMS else { return nil }

        let minTau = max(2, Int(effectiveRate / maximumFrequency))
        let maxTau = min(samples.count / 2, Int(effectiveRate / minimumFrequency))
        guard maxTau > minTau + 2 else { return nil }

        var difference = Array(repeating: 0.0, count: maxTau + 1)
        for tau in 1...maxTau {
            var sum = 0.0
            let limit = samples.count - tau
            if limit <= 0 { break }
            for i in 0..<limit {
                let delta = samples[i] - samples[i + tau]
                sum += delta * delta
            }
            difference[tau] = sum
        }

        var cmnd = Array(repeating: 1.0, count: maxTau + 1)
        var runningSum = 0.0
        if maxTau >= 1 {
            for tau in 1...maxTau {
                runningSum += difference[tau]
                cmnd[tau] = runningSum > 0 ? difference[tau] * Double(tau) / runningSum : 1.0
            }
        }

        var chosenTau: Int?
        var tau = minTau
        while tau <= maxTau {
            if cmnd[tau] < threshold {
                while tau + 1 <= maxTau, cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                chosenTau = tau
                break
            }
            tau += 1
        }

        if chosenTau == nil {
            let searchRange = minTau...maxTau
            chosenTau = searchRange.min(by: { cmnd[$0] < cmnd[$1] })
        }

        guard let periodIndex = chosenTau, cmnd[periodIndex] < 0.45 else { return nil }

        var refinedTau = Double(periodIndex)
        if periodIndex > 1, periodIndex < maxTau {
            let left = cmnd[periodIndex - 1]
            let center = cmnd[periodIndex]
            let right = cmnd[periodIndex + 1]
            let denominator = 2.0 * (2.0 * center - right - left)
            if abs(denominator) > 1e-12 {
                refinedTau += (right - left) / denominator
            }
        }

        guard refinedTau > 0 else { return nil }
        let frequency = effectiveRate / refinedTau
        guard frequency >= minimumFrequency * 0.8, frequency <= maximumFrequency * 1.2 else { return nil }

        return DetectedPitch(
            frequency: frequency,
            confidence: max(0, min(1, 1.0 - cmnd[periodIndex])),
            rms: rms,
            timestamp: timestamp
        )
    }
}
