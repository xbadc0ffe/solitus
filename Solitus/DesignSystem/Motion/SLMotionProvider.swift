import Foundation
import Observation

/// A tilt vector with x and y between -1 and 1. Zero means the device is
/// held level, or that motion is off.
nonisolated struct SLTilt: Hashable, Sendable {
    var x: Double
    var y: Double

    static let zero = SLTilt(x: 0, y: 0)
}

/// Where tilt comes from (DESIGN.md 4.3). Adding a source means adding one
/// case here and one file beside `StaticMotion.swift`.
nonisolated enum SLMotionSource: String, CaseIterable, Sendable {
    /// Always zero. Called `static` in the design guide.
    case still = "static"
    // Planned: device (Core Motion).
}

/// Publishes the current tilt. The root view owns one provider and passes
/// its `tilt` down through the environment as `\.slTilt`.
@Observable
final class SLMotionProvider {
    let source: SLMotionSource
    private(set) var tilt: SLTilt = .zero

    init(source: SLMotionSource = .still) {
        self.source = source
    }

    /// Begins updates. Call when the scene becomes active.
    func start() {
        switch source {
        case .still:
            tilt = StaticMotion.tilt
        }
    }

    /// Stops updates. Call when the scene leaves the foreground, and for
    /// Reduce Motion and Low Power Mode (DESIGN.md 9.5).
    func stop() {
        tilt = .zero
    }
}
