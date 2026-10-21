import Foundation

/// Pure animation timing, shared with tests. Progress is normalized to the available ledge.
public struct MikoMotion: Equatable {
    public let frame: Int
    public let progress: Double
    public let facesLeft: Bool
    public var tilt: Double = 0
    public var breath: Double = 1
    public static func sample(elapsed: TimeInterval, reading: Bool, reduceMotion: Bool) -> MikoMotion {
        if reduceMotion { return MikoMotion(frame: reading ? 8 : 0, progress: 0, facesLeft: false) }
        let t = max(0, elapsed.isFinite ? elapsed : 0)
        if reading { return MikoMotion(frame: t.truncatingRemainder(dividingBy: 6) >= 5.8 ? 9 : 8, progress: 0, facesLeft: false, tilt: sin(t / 3) * 2, breath: 1 + sin(t * 1.5) * 0.012) }
        let cycle = t.truncatingRemainder(dividingBy: 28)
        let moving = cycle < 10 || (cycle >= 14 && cycle < 24)
        let linear = cycle < 10 ? cycle / 10 : cycle < 14 ? 1 : cycle < 24 ? 1 - (cycle - 14) / 10 : 0
        // Gentle acceleration/deceleration at each end rather than a sudden stop.
        let eased = linear * linear * (3 - 2 * linear)
        let look = [12, 12, 13, 13, 14, 12, 15, 12]
        let groom = [12, 16, 17, 18, 17, 18, 16, 19]
        let idleIndex = min(7, Int((cycle < 14 ? cycle - 10 : cycle - 24) * 2))
        let idleFrame = (cycle < 14 ? look : groom)[max(0, idleIndex)]
        return MikoMotion(frame: moving ? Int(t.truncatingRemainder(dividingBy: 2) * 12) % 8 : idleFrame,
                          progress: eased, facesLeft: moving && cycle >= 14,
                          tilt: moving ? 0 : sin(t * 1.4) * 5,
                          breath: 1 + sin(t * 1.8) * (moving ? 0.008 : 0.02))
    }
}
