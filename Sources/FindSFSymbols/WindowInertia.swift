import CoreGraphics
import Foundation

/// Turns window movement into the velocity change that the symbols feel.
/// The scene is a moving frame of reference. Its contents feel only the change of its velocity:
/// a steady move gives nothing, a start pushes the contents back, a stop pushes them forward.
struct WindowInertia {
    /// Mouse events and frames do not line up, so raw velocity samples jitter. This smooths them.
    private let smoothingTime = 0.07
    private var lastOrigin: CGPoint?
    private var lastTime: TimeInterval = 0
    private var velocity = CGVector.zero

    /// Call one time per frame. Returns the velocity change for every free body, in points per second.
    mutating func velocityChange(origin: CGPoint, time: TimeInterval) -> CGVector {
        defer {
            lastOrigin = origin
            lastTime = time
        }
        guard let lastOrigin, time > lastTime, time - lastTime < 0.1 else {
            velocity = .zero
            return .zero
        }
        let dt = time - lastTime
        let dx = origin.x - lastOrigin.x, dy = origin.y - lastOrigin.y
        // A jump is a window snap or a display change. It is not a throw.
        guard hypot(dx, dy) < 400 else {
            velocity = .zero
            return .zero
        }
        let blend = 1 - exp(-dt / smoothingTime)
        let smoothed = CGVector(
            dx: velocity.dx + (dx / dt - velocity.dx) * blend,
            dy: velocity.dy + (dy / dt - velocity.dy) * blend)
        let change = CGVector(dx: velocity.dx - smoothed.dx, dy: velocity.dy - smoothed.dy)
        velocity = smoothed
        return change
    }
}
