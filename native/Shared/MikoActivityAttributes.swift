#if os(iOS)
import ActivityKit
import Foundation

struct MikoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var breakStarted: Date?
    }
    let started: Date
    let expires: Date
}
#endif
