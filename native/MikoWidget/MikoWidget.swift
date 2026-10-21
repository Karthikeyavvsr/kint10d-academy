import SwiftUI
import WidgetKit
import ActivityKit

@main struct MikoWidgets: WidgetBundle {
    var body: some Widget { MikoLiveActivity() }
}
struct MikoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MikoActivityAttributes.self) { context in
            HStack(spacing: 12) {
                MikoIslandPortrait(onBreak: context.state.breakStarted != nil).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.isStale ? "Session finished" : context.state.breakStarted == nil ? "Learning with Miko" : "Taking a breather").font(.headline)
                    Text(context.isStale ? "Open Academy to begin again" : "Tap to return to Academy").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !context.isStale, let start = context.state.breakStarted {
                    Text(timerInterval: start...context.attributes.expires, countsDown: false).monospacedDigit().frame(width: 64)
                }
            }.padding(16).activityBackgroundTint(Color(white: 0.12)).activitySystemActionForegroundColor(.white)
                .foregroundStyle(.white).widgetURL(URL(string: "academy://resume"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { MikoIslandPortrait(onBreak: context.state.breakStarted != nil).frame(width: 44, height: 44) }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale, let start = context.state.breakStarted {
                        Text(timerInterval: start...context.attributes.expires, countsDown: false).monospacedDigit().frame(width: 65)
                    } else { Image(systemName: context.isStale ? "checkmark" : "book") }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? "Session finished · Open Academy" : context.state.breakStarted == nil ? "Learning together" : "Taking a breather · Back to learning").font(.caption)
                }
            } compactLeading: {
                MikoIslandPortrait(onBreak: context.state.breakStarted != nil).frame(width: 25, height: 25)
            } compactTrailing: {
                if !context.isStale, let start = context.state.breakStarted {
                    Text(timerInterval: start...context.attributes.expires, countsDown: false).monospacedDigit().font(.caption2).frame(width: 44)
                } else { Image(systemName: context.isStale ? "checkmark" : "book.closed").foregroundStyle(.white) }
            } minimal: {
                MikoIslandPortrait(onBreak: context.state.breakStarted != nil).frame(width: 24, height: 24)
            }.widgetURL(URL(string: "academy://resume")).keylineTint(.gray)
        }
    }
}

/// State-driven expression changes; no unsupported background animation loop.
private struct MikoIslandPortrait: View {
    var onBreak: Bool
    var body: some View {
        MikoSprite(frame: onBreak ? 11 : 8)
            .id(onBreak)
            .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
    }
}
