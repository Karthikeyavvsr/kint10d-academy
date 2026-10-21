import Foundation

/// Pure animation timing, shared with tests. Progress is normalized to the available ledge.
public struct MikoMotion: Equatable {
    public let frame: Int
    public let progress: Double
    public let facesLeft: Bool
    public static func sample(elapsed: TimeInterval, reading: Bool, reduceMotion: Bool) -> MikoMotion {
        if reduceMotion { return MikoMotion(frame: reading ? 8 : 0, progress: 0, facesLeft: false) }
        let t = max(0, elapsed.isFinite ? elapsed : 0)
        if reading { return MikoMotion(frame: t.truncatingRemainder(dividingBy: 6) >= 5.8 ? 9 : 8, progress: 0, facesLeft: false) }
        let cycle = t.truncatingRemainder(dividingBy: 28)
        let moving = cycle < 10 || (cycle >= 14 && cycle < 24)
        let linear = cycle < 10 ? cycle / 10 : cycle < 14 ? 1 : cycle < 24 ? 1 - (cycle - 14) / 10 : 0
        // Gentle acceleration/deceleration at each end rather than a sudden stop.
        let eased = linear * linear * (3 - 2 * linear)
        return MikoMotion(frame: moving ? Int(t.truncatingRemainder(dividingBy: 2) * 12) % 8 : 0,
                          progress: eased, facesLeft: cycle >= 14)
    }
}
