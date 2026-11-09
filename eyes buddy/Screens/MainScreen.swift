import SwiftUI
import UIKit

struct MainScreen: View {
    @Environment(EyesActivityController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var touch: CGPoint?
    @State private var isClosed = false
    @State private var blinkCount = 0
    @State private var releaseTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let hasIsland = geo.safeAreaInsets.top >= EyeStyle.islandSafeAreaTop
            let layout = EyesLayout(width: geo.size.width, safeTop: geo.safeAreaInsets.top, hasIsland: hasIsland)

            // Extends under the safe area so coordinates start at the screen's top-left,
            // while `geo` above still reports the real insets.
            ZStack(alignment: .topLeading) {
                EyeStyle.ground

                VStack(spacing: 0) {
                    Color.clear.frame(height: layout.contentTop)
                    ScrollView {
                        content(layout: layout)
                            .padding(.horizontal, EyeStyle.margin)
                            .padding(.bottom, 60)
                    }
                    .scrollIndicators(.hidden)
                }

                eyes(layout: layout)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // Simultaneous so tracking works everywhere, including drags that start on the eyes
            // and drags that scroll the page. Attached after ignoresSafeArea so locations share
            // the eyes' screen coordinates.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        releaseTask?.cancel()
                        touch = value.location
                    }
                    .onEnded { _ in
                        // Pupils stay put for 1.5 s, then drift back to center.
                        releaseTask = Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            guard !Task.isCancelled else { return }
                            touch = nil
                        }
                    }
            )
        }
        .background(EyeStyle.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: blinkCount)
    }

    // MARK: Eyes

    private func eyes(layout: EyesLayout) -> some View {
        let d = EyeStyle.appEye
        return ZStack(alignment: .topLeading) {
            if let pill = layout.pill {
                // Continues the real island downward so it looks like it grew a face.
                RoundedRectangle(cornerRadius: EyeStyle.islandSize.height / 2 + 6)
                    .fill(EyeStyle.island)
                    .frame(width: pill.width, height: pill.height)
                    .position(x: pill.midX, y: pill.midY)
            }
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let look = eyeLook(at: timeline.date)
                // Fills the screen so `.position` is measured from the screen's top-left corner.
                ZStack(alignment: .topLeading) {
                    ForEach(Array(layout.eyeCenters.enumerated()), id: \.offset) { _, center in
                        EyeView(
                            diameter: d,
                            pupilOffset: touch.map { FingerTracker.offset(from: center, to: $0) } ?? .zero,
                            isClosed: isClosed,
                            isRed: look.isRed,
                            isTiring: look.isTiring
                        )
                        .position(x: center.x, y: center.y)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.15), value: touch)
        // This layer fills the screen, so it must never take hits or it blocks every control below.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Only this small area (offset, so it doesn't grow the layout) receives taps.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: layout.tapRect.width, height: layout.tapRect.height)
                .contentShape(Rectangle())
                .onTapGesture { blink() }
                .offset(x: layout.tapRect.minX, y: layout.tapRect.minY)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L(controller.isRunning ? "Googly eyes, watching the timer" : "Googly eyes"))
                .accessibilityHint(L("Tap to blink"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { blink() }
        }
    }

    /// Red when time is up, "tiring" over the last 15 %.
    private func eyeLook(at now: Date) -> (isRed: Bool, isTiring: Bool) {
        guard let start = controller.startDate else { return (false, false) }
        let elapsed = now.timeIntervalSince(start)
        let total = TimeInterval(controller.totalSeconds)
        return (elapsed >= total, elapsed >= total * 0.85 && elapsed < total)
    }

    private func blink() {
        guard !isClosed else { return }
        blinkCount += 1
        isClosed = true
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            isClosed = false
        }
    }

    // MARK: Content

    private func content(layout: EyesLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eyes Buddy")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(minHeight: EyeStyle.minTapTarget, alignment: .leading)
                .padding(.top, 8)

            if !controller.activitiesEnabled && controller.islandEnabled && controller.isRunning {
                disabledBanner
                    .padding(.top, 8)
            }

            TimerPanel(bigSize: layout.hasIsland ? 80 : 64)

            SettingsSections()
                .padding(.top, 32)
        }
    }

    private var disabledBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Live Activities are off"))
                .font(.system(size: 15, weight: .heavy))
            Text(L("The eyes can't move into your Dynamic Island until you allow Live Activities for Eyes Buddy."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EyeStyle.secondaryText)
            Button(L("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(EyeStyle.redCopy)
            .frame(minHeight: EyeStyle.minTapTarget, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EyeStyle.surface)
        .overlay(alignment: .leading) { Rectangle().fill(EyeStyle.accent).frame(width: 4) }
    }
}

/// Hint, countdown, progress and the start / stop controls.
private struct TimerPanel: View {
    @Environment(EyesActivityController.self) private var controller
    let bigSize: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let total = TimeInterval(controller.totalSeconds)
            let elapsed = controller.startDate.map { max(0, timeline.date.timeIntervalSince($0)) }
            let finished = elapsed.map { $0 >= total } ?? false
            let remaining = max(0, total - (elapsed ?? 0))

            VStack(alignment: .leading, spacing: 0) {
                Text(hint(running: elapsed != nil, finished: finished))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(finished ? EyeStyle.redCopy : EyeStyle.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: EyeStyle.hintAreaHeight, alignment: .leading)

                Rectangle().fill(EyeStyle.rule).frame(height: 2)

                Text(L(elapsed == nil ? "Timer" : "Time left"))
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.9)
                    .textCase(.uppercase)
                    .foregroundStyle(finished ? EyeStyle.redCopy : EyeStyle.secondaryText)
                    .padding(.top, 16)

                Text(DurationFormat.clock(remaining.rounded(.up)))
                    .font(.system(size: bigSize, weight: .heavy).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(finished ? EyeStyle.redCopy : .white)
                    .accessibilityLabel(finished ? L("Time's up") : L("Time left %@", DurationFormat.short(Int(remaining.rounded(.up)))))

                ProgressView(value: min(elapsed ?? 0, total), total: max(total, 1))
                    .progressViewStyle(.linear)
                    .tint(EyeStyle.accent)
                    .padding(.top, 8)

                HStack {
                    footerLeading(finished: finished)
                    Spacer()
                    Text(L("Total %@", DurationFormat.short(controller.totalSeconds)))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(finished ? EyeStyle.redCopy : EyeStyle.secondaryText)
                .padding(.top, 8)

                controls(running: elapsed != nil, finished: finished)
                    .padding(.top, 20)
            }
        }
    }

    private func hint(running: Bool, finished: Bool) -> String {
        if finished { return L("Time's up! 👀") }
        return L(running ? "Drag your finger, they're watching the clock." : "Pick a time, then start. They'll keep an eye on it.")
    }

    @ViewBuilder
    private func footerLeading(finished: Bool) -> some View {
        if finished {
            Text(L("Time's up! 👀"))
        } else if let end = controller.endDate {
            HStack(spacing: 4) {
                Text(L("Ends at"))
                Text(end, style: .time)
            }
        } else {
            Text(L("Not started"))
        }
    }

    private func controls(running: Bool, finished: Bool) -> some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if running { await controller.stopTimer() } else { await controller.startTimer() }
                }
            } label: {
                Text(L(finished ? "Stop alarm" : running ? "Stop timer" : "Start timer"))
                    .font(.system(size: 17, weight: .heavy))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(.white)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if running {
                Button {
                    Task { await controller.startTimer() }
                } label: {
                    Text(L("Restart"))
                        .font(.system(size: 17, weight: .heavy))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .overlay(Rectangle().stroke(.white, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Positions of the in-app eyes and the pill that joins them to the island.
private struct EyesLayout {
    let hasIsland: Bool
    let eyeCenters: [CGPoint]
    let pill: CGRect?
    let tapRect: CGRect
    let contentTop: CGFloat

    init(width: CGFloat, safeTop: CGFloat, hasIsland: Bool) {
        self.hasIsland = hasIsland
        let d = EyeStyle.appEye
        let mid = width / 2

        if hasIsland {
            // Eyes sit just below the island, clear of the status bar, on a pill that extends the island.
            let islandBottom = EyeStyle.islandTop + EyeStyle.islandSize.height
            let centerY = islandBottom + EyeStyle.appPillPadding + d / 2
            let dx = EyeStyle.appEyePairGap / 2 + d / 2
            eyeCenters = [CGPoint(x: mid - dx, y: centerY), CGPoint(x: mid + dx, y: centerY)]
            let pillW = max(EyeStyle.islandSize.width, 2 * (dx + d / 2 + EyeStyle.appPillPadding))
            let pillBottom = centerY + d / 2 + EyeStyle.appPillPadding
            pill = CGRect(x: mid - pillW / 2, y: EyeStyle.islandTop, width: pillW, height: pillBottom - EyeStyle.islandTop)
            tapRect = CGRect(x: mid - pillW / 2, y: islandBottom, width: pillW, height: pillBottom - islandBottom)
            contentTop = pillBottom + 12
        } else {
            let centerY = max(safeTop, 20) + 8 + d / 2
            let dx = EyeStyle.appEyePairGap / 2 + d / 2
            eyeCenters = [CGPoint(x: mid - dx, y: centerY), CGPoint(x: mid + dx, y: centerY)]
            pill = nil
            tapRect = CGRect(x: mid - dx - d / 2, y: centerY - d / 2, width: 2 * (dx + d / 2), height: d)
            contentTop = centerY + d / 2 + 16
        }
    }
}

#Preview {
    MainScreen()
        .environment(EyesActivityController())
        .environment(LanguageModel())
}

#Preview("日本語") {
    let _ = AppLanguage.choice = .ja
    MainScreen()
        .environment(EyesActivityController())
        .environment(LanguageModel())
        .environment(\.locale, AppLanguage.ja.locale)
}

#Preview("العربية (RTL)") {
    let _ = AppLanguage.choice = .ar
    MainScreen()
        .environment(EyesActivityController())
        .environment(LanguageModel())
        .environment(\.locale, AppLanguage.ar.locale)
        .environment(\.layoutDirection, .rightToLeft)
}
