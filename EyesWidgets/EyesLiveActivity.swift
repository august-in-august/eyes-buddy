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
                    BlinkEye(context: context, mirrored: false, diameter: EyeStyle.expandedEye)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BlinkEye(context: context, mirrored: true, diameter: EyeStyle.expandedEye)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WatchingInfo(context: context, showsBlinkHint: true)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }
            } compactLeading: {
                ContextEye(context: context, mirrored: false, diameter: EyeStyle.compactEye)
            } compactTrailing: {
                ContextEye(context: context, mirrored: true, diameter: EyeStyle.compactEye)
            } minimal: {
                ContextEye(context: context, mirrored: false, diameter: EyeStyle.minimalEye)
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

/// One eye drawn from the activity state. The trailing eye mirrors the glance so both look inward.
private struct ContextEye: View {
    let context: ActivityViewContext<EyesAttributes>
    let mirrored: Bool
    let diameter: CGFloat

    var body: some View {
        let o = context.state.pupilOffset
        EyeView(
            diameter: diameter,
            pupilOffset: CGVector(dx: mirrored ? -o.dx : o.dx, dy: o.dy),
            isClosed: context.state.isClosed,
            isRed: context.isRed
        )
    }
}

/// An eye wrapped in the blink button, with a tap target of at least 44 pt.
private struct BlinkEye: View {
    let context: ActivityViewContext<EyesAttributes>
    let mirrored: Bool
    let diameter: CGFloat

    var body: some View {
        Button(intent: BlinkIntent()) {
            ContextEye(context: context, mirrored: mirrored, diameter: diameter)
                .frame(minWidth: EyeStyle.minTapTarget, minHeight: EyeStyle.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Blink")
    }
}

/// Kicker, timer and progress bar toward the red limit.
private struct WatchingInfo: View {
    let context: ActivityViewContext<EyesAttributes>
    let showsBlinkHint: Bool

    var body: some View {
        let red = context.isRed
        let redDate = context.attributes.redDate(for: context.state)

        VStack(spacing: 6) {
            Text(red ? "You've been staring for a while 👀" : (showsBlinkHint ? "Tap me to blink" : "Watching you for"))
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.9)
                .textCase(.uppercase)
                .foregroundStyle(red ? EyeStyle.redCopy : EyeStyle.secondaryText)

            HStack(spacing: 6) {
                Text("Watching you for")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
                Text(timerInterval: context.attributes.watchingRange, pauseTime: nil, countsDown: false, showsHours: true)
                    .font(.system(size: 22, weight: .heavy).monospacedDigit())
                    .foregroundStyle(red ? EyeStyle.redCopy : .white)
            }

            ProgressView(timerInterval: context.attributes.limitRange(for: context.state), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(EyeStyle.accent)

            HStack {
                if red {
                    Text("Past your limit")
                } else {
                    HStack(spacing: 4) {
                        Text("Red in")
                        Text(timerInterval: .now...max(.now.addingTimeInterval(1), redDate), countsDown: true, showsHours: true)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Text("Limit \(Self.limitLabel(context.state.redLimitSeconds))")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(EyeStyle.secondaryText)
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
            BlinkEye(context: context, mirrored: false, diameter: EyeStyle.lockScreenEye)
            WatchingInfo(context: context, showsBlinkHint: false)
            BlinkEye(context: context, mirrored: true, diameter: EyeStyle.lockScreenEye)
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
    fileprivate static let open = EyesAttributes.ContentState(isClosed: false, pupilOffset: CGVector(dx: 0.8, dy: 0.35), redLimitSeconds: 7200)
    fileprivate static let closed = EyesAttributes.ContentState(isClosed: true, pupilOffset: CGVector(dx: 0.8, dy: 0.35), redLimitSeconds: 7200)
    fileprivate static let redOpen = EyesAttributes.ContentState(isClosed: false, pupilOffset: CGVector(dx: 0.8, dy: 0.35), redLimitSeconds: 60)
    fileprivate static let redClosed = EyesAttributes.ContentState(isClosed: true, pupilOffset: CGVector(dx: 0.8, dy: 0.35), redLimitSeconds: 60)
}

#Preview("Compact · white", as: .dynamicIsland(.compact), using: EyesAttributes.preview) {
    EyesLiveActivity()
} contentStates: {
    EyesAttributes.ContentState.open
    EyesAttributes.ContentState.closed
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
