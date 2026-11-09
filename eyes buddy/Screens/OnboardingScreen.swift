import SwiftUI

struct OnboardingScreen: View {
    @Environment(EyesActivityController.self) private var controller
    var onFinish: () -> Void

    @State private var page = 0
    @State private var total = SharedSettings.totalSeconds
    private let pageCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(format: "%02d / %02d", page + 1, pageCount))
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.9)
                    .foregroundStyle(EyeStyle.secondaryText)
                Spacer()
                LanguageMenu(style: .compact)
                if page < pageCount - 1 {
                    Button(L("Skip")) { page = pageCount - 1 }
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
                        await controller.setTotal(total)
                        await controller.setIslandEnabled(true)
                        await TimerNotifications.requestAuthorization()
                        onFinish()
                    }
                }
            } label: {
                Text(L(page < pageCount - 1 ? "Next" : "Get started"))
                    .font(.system(size: 17, weight: .heavy))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(.white)
            }
            .buttonStyle(.plain)

            Text(page == pageCount - 1 ? L("iOS will ask to allow notifications so the alarm can ring.") : " ")
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
            headline(L("Meet your eyes"))
            body(L("A tiny creature lives in your camera cutout. Start a timer and it keeps watch, blinks when you poke it, and turns red when time runs out."))
        }
    }

    private var island: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                EyeView(diameter: 60, pupilOffset: CGVector(dx: 0.8, dy: 0.35))
                Text(L("Tap me to blink"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EyeStyle.secondaryText)
                EyeView(diameter: 60, isClosed: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 28).fill(.black))
            headline(L("They live in your Dynamic Island"))
            body(L("Long-press the island to open the big eyes. Tap an eye and it blinks back at you."))
        }
    }

    private var setLimit: some View {
        VStack(alignment: .leading, spacing: 20) {
            headline(L("Set your timer"))
            body(L("When time runs out, the eyes turn red and growl. Change the time whenever you like."))
            TimerPicker(seconds: $total)
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
