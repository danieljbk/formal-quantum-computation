import CoreMotion
import Foundation

/// Accelerometer and pedometer feeds for the shake and walking missions.
@MainActor
final class MotionService: ObservableObject {
    @Published private(set) var shakes = 0
    @Published private(set) var steps = 0
    @Published private(set) var isAvailable = true

    private let motion = CMMotionManager()
    private let pedometer = CMPedometer()
    private var shakeCounter = ShakeCounter(difficulty: .medium)
    private var stepDetector = StepDetector()
    private var usingPedometer = false
    private var onEvent: (() -> Void)?

    func startShakes(difficulty: MissionDifficulty, onShake: @escaping () -> Void) {
        stop()
        shakeCounter = ShakeCounter(difficulty: difficulty)
        shakes = 0
        onEvent = onShake
        guard motion.isAccelerometerAvailable else {
            isAvailable = false
            return
        }
        motion.accelerometerUpdateInterval = 1.0 / 50
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.acceleration else { return }
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let time = data?.timestamp ?? 0
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.shakeCounter.add(magnitude: magnitude, at: time) {
                    self.shakes = self.shakeCounter.count
                    self.onEvent?()
                }
            }
        }
    }

    func startSteps(onStep: @escaping () -> Void) {
        stop()
        steps = 0
        onEvent = onStep
        stepDetector = StepDetector()
        if CMPedometer.isStepCountingAvailable() {
            usingPedometer = true
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let count = data?.numberOfSteps.intValue else { return }
                Task { @MainActor in
                    guard let self, count > self.steps else { return }
                    self.steps = count
                    self.onEvent?()
                }
            }
        } else if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 50
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let a = data?.acceleration else { return }
                let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                let time = data?.timestamp ?? 0
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.stepDetector.add(magnitude: magnitude, at: time) {
                        self.steps = self.stepDetector.steps
                        self.onEvent?()
                    }
                }
            }
        } else {
            isAvailable = false
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        if usingPedometer { pedometer.stopUpdates() }
        usingPedometer = false
        onEvent = nil
    }
}
