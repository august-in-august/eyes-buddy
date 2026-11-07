import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct EyesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EyesAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let red = context.isRed
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BlinkEye(context: context, rightEye: false, diameter: EyeStyle.expandedEye, expanded: true)
                        .padding(.top, 6)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BlinkEye(context: context, rightEye: true, diameter: EyeStyle.expandedEye, expanded: true)
                        .padding(.top, 6)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    WatchingTimer(context: context, timerSize: 24)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressFooter(context: context)
                        .padding(.horizontal, 12)
                }
            } compactLeading: {
                ContextEye(context: context, diameter: EyeStyle.compactEye)
            } compactTrailing: {
                ContextEye(context: context, diameter: EyeStyle.compactEye)
            } minimal: {
                ContextEye(context: context, diameter: EyeStyle.minimalEye)
            }
            .keylineTint(red ? EyeStyle.accent : .white)
        }
    }
}

// MARK: - Helpers

extension ActivityViewContext<EyesAttributes> {
    /// `isStale` is the real trigger (staleDate); the date check keeps previews and late renders honest.
    var isRed: Bool {
        isStale || attributes.redDate(for: state) <= .now
    }
}

/// One eye drawn from the activity state. Compact, minimal and Lock Screen eyes look the same way.
private struct ContextEye: View {
    let context: ActivityViewContext<EyesAttributes>
    let diameter: CGFloat

    var body: some View {
        EyeView(
            diameter: diameter,
            pupilOffset: context.state.pupilOffset,
            isClosed: context.state.isClosed,
            isRed: context.isRed,
            closure: context.state.lid
        )
    }
}

/// An eye wrapped in the blink button, with a tap target of at least 44 pt.
/// In the expanded view the left/right eyes follow the sweep animation instead of the shared glance.
private struct BlinkEye: View {
    let context: ActivityViewContext<EyesAttributes>
    let rightEye: Bool
    let diameter: CGFloat
    var expanded = false

    var body: some View {
        Button(intent: BlinkIntent()) {
            EyeView(
                diameter: diameter,
                pupilOffset: expanded ? context.state.expandedOffset(rightEye: rightEye) : context.state.pupilOffset,
                isClosed: context.state.isClosed,
                isRed: context.isRed,
                closure: context.state.lid
            )
            .frame(minWidth: EyeStyle.minTapTarget, minHeight: EyeStyle.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Blink")
    }
}

/// "Watching you for" label with the self-updating timer.
private struct WatchingTimer: View {
    let context: ActivityViewContext<EyesAttributes>
    let timerSize: CGFloat

    var body: some View {
        let red = context.isRed
        VStack(spacing: 2) {
            Text("Watching you for")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EyeStyle.secondaryText)
            Text(timerInterval: context.attributes.watchingRange, pauseTime: nil, countsDown: false, showsHours: true)
                .font(.system(size: timerSize, weight: .heavy).monospacedDigit())
                .foregroundStyle(red ? EyeStyle.redCopy : .white)
                .multilineTextAlignment(.center)
        }
    }
}

/// Progress bar toward the red limit, with "Red in …" / the red-state copy and the limit.
private struct ProgressFooter: View {
    let context: ActivityViewContext<EyesAttributes>

    var body: some View {
        let red = context.isRed
        let redDate = context.attributes.redDate(for: context.state)

        VStack(spacing: 6) {
            ProgressView(timerInterval: context.attributes.limitRange(for: context.state), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(EyeStyle.accent)

            HStack {
                if red {
                    Text("You've been staring for a while 👀")
                        .foregroundStyle(EyeStyle.redCopy)
                } else {
                    HStack(spacing: 4) {
                        Text("Red in")
                        Text(timerInterval: .now...max(.now.addingTimeInterval(1), redDate), countsDown: true, showsHours: true)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 8)
                Text("Limit \(Self.limitLabel(context.state.redLimitSeconds))")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(EyeStyle.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    static func limitLabel(_ seconds: Int) -> String {
        seconds >= 3600 && seconds % 3600 == 0 ? "\(seconds / 3600) h" : "\(seconds / 60) min"
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<EyesAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            BlinkEye(context: context, rightEye: false, diameter: EyeStyle.lockScreenEye)
            VStack(spacing: 10) {
                WatchingTimer(context: context, timerSize: 24)
                ProgressFooter(context: context)
            }
            BlinkEye(context: context, rightEye: true, diameter: EyeStyle.lockScreenEye)
        }
        .padding(EyeStyle.margin)
    }
}

// MARK: - Previews

extension EyesAttributes {
    /// Limit not yet reached.
    fileprivate static let preview = EyesAttributes(sessionStart: .now.addingTimeInterval(-83 * 60))
    /// Started 3 h ago with a 60 s limit, so every view renders red.
    fileprivate static let previewRed = EyesAttributes(sessionStart: .now.addingTimeInterval(-3 * 3600))
}

extension EyesAttributes.ContentState {
    private static func sample(closed: Bool = false, lid: Double = 0, sweep: Double = -1, limit: Int) -> Self {
        EyesAttributes.ContentState(
            isClosed: closed, pupilOffset: CGVector(dx: 0.6, dy: -0.5),
            lid: lid, sweep: sweep, redLimitSeconds: limit
        )
    }
    fileprivate static let open = sample(limit: 7200)
    fileprivate static let closed = sample(closed: true, limit: 7200)
    fileprivate static let sleepy = sample(lid: 0.5, limit: 7200)
    fileprivate static let sweeping = sample(sweep: 0.5, limit: 7200)
    fileprivate static let redOpen = sample(limit: 60)
    fileprivate static let redClosed = sample(closed: true, limit: 60)
}

#Preview("Compact · white", as: .dynamicIsland(.compact), using: EyesAttributes.preview) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.open
    EyesAttributes.ContentState.closed
    EyesAttributes.ContentState.sleepy
}

#Preview("Compact · red", as: .dynamicIsland(.compact), using: EyesAttributes.previewRed) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.redOpen
    EyesAttributes.ContentState.redClosed
}

#Preview("Minimal · white", as: .dynamicIsland(.minimal), using: EyesAttributes.preview) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.open
    EyesAttributes.ContentState.closed
}

#Preview("Minimal · red", as: .dynamicIsland(.minimal), using: EyesAttributes.previewRed) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.redOpen
    EyesAttributes.ContentState.redClosed
}

#Preview("Expanded · white", as: .dynamicIsland(.expanded), using: EyesAttributes.preview) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.open
    EyesAttributes.ContentState.sweeping
    EyesAttributes.ContentState.closed
}

#Preview("Expanded · red", as: .dynamicIsland(.expanded), using: EyesAttributes.previewRed) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.redOpen
    EyesAttributes.ContentState.redClosed
}

#Preview("Lock Screen · white", as: .content, using: EyesAttributes.preview) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.open
    EyesAttributes.ContentState.closed
}

#Preview("Lock Screen · red", as: .content, using: EyesAttributes.previewRed) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.redOpen
    EyesAttributes.ContentState.redClosed
}
