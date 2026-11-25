import CoreMotion
import Foundation

/// Counts shakes from the accelerometer. The counting rule is a pure function so it can be tested.
final class ShakeDetector: ObservableObject {
    @Published private(set) var count = 0

    private let manager = CMMotionManager()
    private var counter = ShakeCounter()

    var isAvailable: Bool { manager.isAccelerometerAvailable }

    func start() {
        count = 0
        counter = ShakeCounter()
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = 1.0 / 50.0
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            if self.counter.feed(x: a.x, y: a.y, z: a.z, at: data!.timestamp) {
                self.count = self.counter.count
            }
        }
    }

    func stop() { manager.stopAccelerometerUpdates() }

    /// Lets the simulator (no accelerometer) and accessibility users progress.
    func registerManualShake() { count += 1; counter.count = count }
}

/// A shake is counted when acceleration magnitude (in g) exceeds `threshold`, at most once per
/// `debounce` seconds.
struct ShakeCounter {
    var threshold = 2.0
    var debounce: TimeInterval = 0.25
    var count = 0
    private var lastShake: TimeInterval = -.infinity

    @discardableResult
    mutating func feed(x: Double, y: Double, z: Double, at time: TimeInterval) -> Bool {
        let magnitude = (x * x + y * y + z * z).squareRoot()
        guard magnitude >= threshold, time - lastShake >= debounce else { return false }
        lastShake = time
        count += 1
        return true
    }
}
