import Foundation

/// Measures main-thread responsiveness by scheduling a high-frequency timer
/// on a background queue and comparing expected vs. actual tick interval.
final class LagMonitor {
    private let queue = DispatchQueue(label: "systempulse.lag", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var lastTick: DispatchTime = .now()
    private let interval: TimeInterval = 0.05 // 50ms
    private var maxLagMs: Double = 0

    /// Exponentially-smoothed current lag in ms.
    private(set) var currentLagMs: Double = 0

    func start() {
        stop()
        lastTick = .now()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = DispatchTime.now()
            let actual = Double(now.uptimeNanoseconds - self.lastTick.uptimeNanoseconds) / 1_000_000.0
            let lag = max(0, actual - self.interval * 1000.0)
            self.currentLagMs = self.currentLagMs * 0.7 + lag * 0.3
            if lag > self.maxLagMs { self.maxLagMs = lag }
            self.lastTick = now
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func snapshot() -> (currentMs: Double, peakMs: Double) {
        (currentLagMs, maxLagMs)
    }

    func resetPeak() { maxLagMs = 0 }
}
