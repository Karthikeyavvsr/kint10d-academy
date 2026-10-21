import SwiftUI
import AcademyCore
#if os(iOS)
import ActivityKit
#endif

struct MikoReadingKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

struct MikoDock: ViewModifier {
    @State private var reading = false
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) { MikoLedge(reading: reading) }
            .onPreferenceChange(MikoReadingKey.self) { reading = $0 }
    }
}

/// A small reserved ledge keeps the artwork away from text and native tab hit targets.
struct MikoLedge: View {
    var reading = false
    @AppStorage("academy.miko.visible") private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var epoch = Date()
    @State private var onScreen = false
    @State private var greetingUntil = Date.distantPast
    var body: some View {
        if visible {
            TimelineView(.animation(minimumInterval: reading ? 1.0 / 12 : 1.0 / 30, paused: reduceMotion || phase != .active || !onScreen)) { context in
                GeometryReader { geometry in
                    let elapsed = max(0, context.date.timeIntervalSince(epoch))
                    let motion = MikoMotion.sample(elapsed: elapsed, reading: reading, reduceMotion: reduceMotion)
                    let width = max(0, geometry.size.width - 68)
                    ZStack(alignment: .bottomLeading) {
                        MikoSprite(frame: context.date < greetingUntil ? 19 : motion.frame)
                            .frame(width: reading ? 49 : 56, height: reading ? 44 : 48)
                            .scaleEffect(x: motion.facesLeft ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(context.date < greetingUntil && !reduceMotion ? sin(elapsed * 4) * 7 : motion.tilt), anchor: .bottom)
                            .scaleEffect(x: 1, y: motion.breath, anchor: .bottom)
                            .contentShape(Rectangle())
                            .onTapGesture { greetingUntil = Date().addingTimeInterval(2.5) }
                            .accessibilityHidden(false)
                            .accessibilityLabel("Say hello to Miko")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { greetingUntil = Date().addingTimeInterval(2.5) }
                            .offset(x: 12 + motion.progress * width, y: reading ? 5 : 3)

                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).clipped()
                }
            }.frame(height: 43)
                .onAppear { onScreen = true; epoch = Date() }
                .onDisappear { onScreen = false }
        }
    }
}

@MainActor final class MikoSession: ObservableObject {
    @Published var running = false
    @Published var message = "Start a one-hour companion session to use the Dynamic Island and Lock Screen."
    #if os(iOS)
    private var activity: Activity<MikoActivityAttributes>?
    private var pending: Task<Void, Never>?
    init() {
        activity = Activity<MikoActivityAttributes>.activities.first
        running = activity != nil
        if running { message = "Your companion session is active. Return to learning, or end it here." }
    }
    func start() {
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities are disabled. Enable them for Academy in iOS Settings."; return
        }
        do {
            let now = Date()
            activity = try Activity.request(attributes: MikoActivityAttributes(started: now, expires: now.addingTimeInterval(3600)), content: ActivityContent(state: .init(breakStarted: nil), staleDate: now.addingTimeInterval(3600)), pushType: nil)
            running = true
            message = "Miko is with you. Switching away starts a break timer; returning resumes your session."
        } catch { message = "Could not start Miko: \(error.localizedDescription)" }
    }
    func changePhase(_ phase: ScenePhase) {
        guard phase != .inactive, let current = activity else { return }
        if current.attributes.expires <= Date() || current.activityState == .dismissed || current.activityState == .ended { stop(); return }
        let previous = pending
        let breakStarted = phase == .background ? Date() : nil
        pending = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await current.update(ActivityContent(state: .init(breakStarted: breakStarted), staleDate: current.attributes.expires))
        }
    }
    func stop() {
        let previous = pending
        let existing = Activity<MikoActivityAttributes>.activities
        activity = nil; running = false
        message = "Session ended. Start another whenever you are ready."
        pending = Task {
            await previous?.value
            for item in existing { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }
    #else
    init() {}
    func changePhase(_ phase: ScenePhase) {}
    #endif
}
