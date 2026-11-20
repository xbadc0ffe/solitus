import Foundation

/// The `static` motion source: no sensors, tilt is always zero.
nonisolated enum StaticMotion {
    static let tilt = SLTilt.zero
}
