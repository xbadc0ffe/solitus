import SwiftUI
import UIKit

/// A press-and-hold that leaves scrolling alone.
///
/// SwiftUI's own long-press gesture, placed on a view inside a scroll view,
/// swallows the drag that should scroll it. This wraps UIKit's recogniser
/// instead and lets it run alongside the scroll view's pan.
///
/// `onBegan` fires once the finger has rested for a moment; `onEnded` fires
/// when it lifts, or when it moves far enough to be a scroll.
struct SLHoldGesture: UIGestureRecognizerRepresentable {
    /// How long the finger must rest before the hold begins.
    static let restTime: TimeInterval = 0.12
    /// A finger that travels further than this is scrolling, not holding.
    private static let maxTravel: CGFloat = 18

    let onBegan: () -> Void
    let onEnded: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint = .zero
        var isHolding = false

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = SLHoldGesture.restTime
        recognizer.allowableMovement = SLHoldGesture.maxTravel
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        switch recognizer.state {
        case .began:
            coordinator.start = recognizer.location(in: nil)
            coordinator.isHolding = true
            onBegan()
        case .changed:
            guard coordinator.isHolding else { return }
            let point = recognizer.location(in: nil)
            let travel = hypot(point.x - coordinator.start.x, point.y - coordinator.start.y)
            if travel > SLHoldGesture.maxTravel {
                coordinator.isHolding = false
                onEnded()
            }
        case .ended, .cancelled, .failed:
            guard coordinator.isHolding else { return }
            coordinator.isHolding = false
            onEnded()
        default:
            break
        }
    }
}
