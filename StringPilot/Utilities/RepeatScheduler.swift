import Foundation

final class RepeatScheduler {
    private let queue = DispatchQueue(label: "StringPilot.RepeatScheduler", qos: .userInteractive)
    private var timers: [Int: DispatchSourceTimer] = [:]

    func start(
        id: Int,
        interval: TimeInterval,
        fireImmediately: Bool = true,
        action: @escaping @Sendable () -> Void
    ) {
        stop(id: id)
        let safeInterval = max(0.015, interval)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: fireImmediately ? .now() : .now() + safeInterval,
            repeating: safeInterval,
            leeway: .milliseconds(1)
        )
        timer.setEventHandler(handler: action)
        timers[id] = timer
        timer.resume()
    }

    func stop(id: Int) {
        guard let timer = timers.removeValue(forKey: id) else { return }
        timer.setEventHandler {}
        timer.cancel()
    }

    func stopAll() {
        let active = timers.values
        timers.removeAll()
        active.forEach {
            $0.setEventHandler {}
            $0.cancel()
        }
    }

    deinit { stopAll() }
}
