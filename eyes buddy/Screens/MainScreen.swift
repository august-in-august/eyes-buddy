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
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let hasIsland = geo.safeAreaInsets.top >= EyeStyle.islandSafeAreaTop
            let layout = EyesLayout(width: geo.size.width, safeTop: geo.safeAreaInsets.top, hasIsland: hasIsland)

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let now = timeline.date
                let elapsed = max(0, now.timeIntervalSince(controller.sessionStart))
                let limit = TimeInterval(controller.redLimitSeconds)
                let isRed = elapsed >= limit
                let isTiring = !isRed && elapsed >= limit * 0.85

                // Extends under the safe area so coordinates start at the screen's top-left,
                // while `geo` above still reports the real insets.
                ZStack(alignment: .topLeading) {
                    EyeStyle.ground

                    content(elapsed: elapsed, limit: limit, isRed: isRed, layout: layout)

                    eyes(layout: layout, isRed: isRed, isTiring: isTiring, elapsed: elapsed)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Simultaneous so tracking works everywhere, including drags that start on the eyes.
                // Attached after ignoresSafeArea so locations share the eyes' screen coordinates.
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
        }
        .background(EyeStyle.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: blinkCount)
        .sheet(isPresented: $showSettings) {
            SettingsScreen()
                .environment(controller)
        }
    }

    // MARK: Eyes

    private func eyes(layout: EyesLayout, isRed: Bool, isTiring: Bool, elapsed: TimeInterval) -> some View {
        let d = EyeStyle.appEye
        return ZStack(alignment: .topLeading) {
            if let pill = layout.pill {
                Capsule().fill(EyeStyle.island)
                    .frame(width: pill.width, height: pill.height)
                    .position(x: pill.midX, y: pill.midY)
            }
            ForEach(Array(layout.eyeCenters.enumerated()), id: \.offset) { _, center in
                EyeView(
                    diameter: d,
                    pupilOffset: touch.map { FingerTracker.offset(from: center, to: $0) } ?? .zero,
                    isClosed: isClosed,
                    isRed: isRed,
                    isTiring: isTiring
                )
                .position(x: center.x, y: center.y)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.15), value: touch)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Googly eyes, watching for \(Int(elapsed / 60)) minutes")
        .accessibilityHint("Tap to blink")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { blink() }
        // The tap target covers only the eyes row so the rest of the screen stays free for tracking.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: layout.tapRect.width, height: layout.tapRect.height)
                .contentShape(Rectangle())
                .onTapGesture { blink() }
                .position(x: layout.tapRect.midX, y: layout.tapRect.midY)
                .accessibilityHidden(true)
        }
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

    private func content(elapsed: TimeInterval, limit: TimeInterval, isRed: Bool, layout: EyesLayout) -> some View {
        let remaining = max(0, limit - elapsed)
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: layout.contentTop)

            HStack {
                Text("Eyes Buddy")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: EyeStyle.minTapTarget, height: EyeStyle.minTapTarget)
                }
                .accessibilityLabel("Settings")
            }
            .padding(.top, 8)

            if !controller.activitiesEnabled && controller.islandEnabled {
                disabledBanner
                    .padding(.top, 8)
            }

            Spacer(minLength: 16)

            Text(controller.islandEnabled ? "Drag your finger, they're watching." : "The eyes are asleep. Wake them?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(EyeStyle.secondaryText)

            Spacer(minLength: 16)

            Rectangle().fill(EyeStyle.rule).frame(height: 2)

            Text("Watching you for")
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.9)
                .textCase(.uppercase)
                .foregroundStyle(isRed ? EyeStyle.redCopy : EyeStyle.secondaryText)
                .padding(.top, 16)

            Text(Self.format(elapsed))
                .font(.system(size: layout.hasIsland ? 80 : 64, weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(isRed ? EyeStyle.redCopy : .white)
                .accessibilityLabel("Watching for \(Int(elapsed / 60)) minutes")

            ProgressView(value: min(elapsed, limit), total: max(limit, 1))
                .progressViewStyle(.linear)
                .tint(EyeStyle.accent)
                .padding(.top, 8)

            HStack {
                Text(isRed ? "Okay… that's a lot of scrolling 👀" : "Red in \(Int((remaining / 60).rounded(.up))) min")
                Spacer()
                Text("Limit \(LimitPicker.label(controller.redLimitSeconds))")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isRed ? EyeStyle.redCopy : EyeStyle.secondaryText)
            .padding(.top, 8)

            Button {
                Task { await controller.setIslandEnabled(!controller.islandEnabled) }
            } label: {
                Text(controller.islandEnabled ? "Put eyes to sleep" : "Wake the eyes")
                    .font(.system(size: 17, weight: .heavy))
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.black)
                    .background(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.bottom, max(20, layout.bottomInset))
        }
        .padding(.horizontal, EyeStyle.margin)
    }

    private var disabledBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Activities are off")
                .font(.system(size: 15, weight: .heavy))
            Text("The eyes can't move into your Dynamic Island until you allow Live Activities for Eyes Buddy.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EyeStyle.secondaryText)
            Button("Open Settings") {
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

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }
}

/// Positions of the in-app eyes and the pill that joins them to the island.
private struct EyesLayout {
    let hasIsland: Bool
    let bottomInset: CGFloat
    let eyeCenters: [CGPoint]
    let pill: CGRect?
    let tapRect: CGRect
    let contentTop: CGFloat

    init(width: CGFloat, safeTop: CGFloat, hasIsland: Bool) {
        self.hasIsland = hasIsland
        bottomInset = hasIsland ? 34 : 20
        let d = EyeStyle.appEye
        let mid = width / 2

        if hasIsland {
            let centerY = EyeStyle.islandTop + EyeStyle.islandSize.height / 2
            let dx = EyeStyle.islandSize.width / 2 + EyeStyle.appEyeGap + d / 2
            eyeCenters = [CGPoint(x: mid - dx, y: centerY), CGPoint(x: mid + dx, y: centerY)]
            let pillW = 2 * (dx + d / 2 + EyeStyle.appPillPadding)
            let pillH = d + 2 * EyeStyle.appPillPadding
            pill = CGRect(x: mid - pillW / 2, y: centerY - pillH / 2, width: pillW, height: pillH)
            tapRect = pill ?? .zero
            contentTop = centerY + pillH / 2 + 16
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
    MainScreen().environment(EyesActivityController())
}
