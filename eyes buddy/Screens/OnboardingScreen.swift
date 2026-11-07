import SwiftUI

struct OnboardingScreen: View {
    @Environment(EyesActivityController.self) private var controller
    var onFinish: () -> Void

    @State private var page = 0
    @State private var limit = SharedSettings.redLimitSeconds
    private let pageCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(format: "%02d / %02d", page + 1, pageCount))
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.9)
                    .foregroundStyle(EyeStyle.secondaryText)
                Spacer()
                if page < pageCount - 1 {
                    Button("Skip") { page = pageCount - 1 }
                        .font(.system(size: 15, weight: .heavy))
                        .frame(minWidth: EyeStyle.minTapTarget, minHeight: EyeStyle.minTapTarget)
                }
            }

            Spacer()

            Group {
                switch page {
                case 0: meet
                case 1: island
                default: setLimit
                }
            }
            .transition(.opacity)

            Spacer()

            Button {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        await controller.setRedLimit(limit)
                        await controller.setIslandEnabled(true)
                        onFinish()
                    }
                }
            } label: {
                Text(page < pageCount - 1 ? "Next" : "Turn on the eyes")
                    .font(.system(size: 17, weight: .heavy))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(.white)
            }
            .buttonStyle(.plain)

            Text(page == pageCount - 1 ? "Next, iOS asks to allow Live Activities." : " ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EyeStyle.secondaryText)
                .padding(.top, 8)
        }
        .padding(EyeStyle.margin)
        .foregroundStyle(.white)
        .background(EyeStyle.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var meet: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                EyeView(diameter: 90, pupilOffset: CGVector(dx: 0.8, dy: 0.35))
                EyeView(diameter: 90, pupilOffset: CGVector(dx: 0.8, dy: 0.35))
            }
            .padding(14)
            .background(Capsule().fill(.black))
            headline("Meet your eyes")
            body("A tiny creature lives in your camera cutout. It watches while you scroll, blinks when you poke it, and gets tired if you stare too long.")
        }
    }

    private var island: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                EyeView(diameter: 60, pupilOffset: CGVector(dx: 0.8, dy: 0.35))
                Text("Tap me to blink")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
                EyeView(diameter: 60, isClosed: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 28).fill(.black))
            headline("They live in your Dynamic Island")
            body("Long-press the island to open the big eyes. Tap an eye and it blinks back at you.")
        }
    }

    private var setLimit: some View {
        VStack(alignment: .leading, spacing: 20) {
            headline("Set how long before they get tired")
            body("Past the limit, the eyes turn red. It's a nudge, not a lock. Change it any time.")
            LimitPicker(seconds: $limit)
        }
    }

    private func headline(_ text: String) -> some View {
        Text(text).font(.system(size: 40, weight: .heavy)).minimumScaleFactor(0.6)
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.system(size: 17, weight: .semibold)).foregroundStyle(EyeStyle.secondaryText)
    }
}

#Preview {
    OnboardingScreen(onFinish: {}).environment(EyesActivityController())
}
