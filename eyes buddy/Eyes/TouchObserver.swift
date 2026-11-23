import SwiftUI
import UIKit

/// Reports every finger movement anywhere in the window, for the eyes that follow your finger,
/// without taking part in hit testing.
///
/// A SwiftUI `DragGesture(minimumDistance: 0)` placed above a `ScrollView` stops it scrolling on
/// iOS 17 (newer systems tolerate it). A plain UIKit recognizer on the window that recognizes
/// alongside every other gesture and never cancels touches leaves scrolling and buttons alone.
struct TouchObserver: UIViewRepresentable {
    /// Called with the finger position in screen coordinates while touching.
    var onChange: (CGPoint) -> Void
    /// Called when the finger lifts or the touch is cancelled.
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
    }

    static func dismantleUIView(_ view: ObserverView, coordinator: Coordinator) {
        view.removeRecognizer()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGPoint) -> Void = { _ in }
        var onEnd: () -> Void = {}

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                onChange(recognizer.location(in: recognizer.view))
            case .ended, .cancelled, .failed:
                onEnd()
            default:
                break
            }
        }

        // Never compete with scrolling, taps or buttons.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }

    /// An invisible, non-interactive view whose only job is to attach the recognizer to the window.
    final class ObserverView: UIView {
        var coordinator: Coordinator?
        private var recognizer: UILongPressGestureRecognizer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            removeRecognizer()
            guard let window, let coordinator else { return }
            // A long press with no delay and unlimited movement is a "touch down ... touch up" tracker.
            let recognizer = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handle(_:)))
            recognizer.minimumPressDuration = 0
            recognizer.allowableMovement = .greatestFiniteMagnitude
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = coordinator
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
        }

        func removeRecognizer() {
            if let recognizer { recognizer.view?.removeGestureRecognizer(recognizer) }
            recognizer = nil
        }
    }
}
