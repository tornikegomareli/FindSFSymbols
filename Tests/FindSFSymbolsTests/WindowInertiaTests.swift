import CoreGraphics
import Testing
@testable import FindSFSymbols

@Suite struct WindowInertiaTests {
    private let frame = 1.0 / 120

    /// Moves the window along x with the given speed per frame. Returns the change of each frame.
    private func run(_ speeds: [Double], inertia: inout WindowInertia) -> [Double] {
        var x = 0.0, time = 0.0
        _ = inertia.velocityChange(origin: .zero, time: time)
        return speeds.map { speed in
            x += speed * frame
            time += frame
            return inertia.velocityChange(origin: CGPoint(x: x, y: 0), time: time).dx
        }
    }

    @Test func steadyMoveGivesNoForce() {
        var inertia = WindowInertia()
        let changes = run(Array(repeating: 300, count: 240), inertia: &inertia)
        // The start pushes the contents back by the full window speed.
        #expect(abs(changes.reduce(0, +) + 300) < 1)
        // After the start, a steady move gives nothing.
        #expect(changes.suffix(120).allSatisfy { abs($0) < 0.01 })
    }

    @Test func startThenStopCancels() {
        var inertia = WindowInertia()
        let speeds = Array(repeating: 500.0, count: 120) + Array(repeating: 0.0, count: 240)
        let changes = run(speeds, inertia: &inertia)
        #expect(abs(changes.reduce(0, +)) < 1)
    }

    @Test func slowMoveIsGentle() {
        var inertia = WindowInertia()
        let changes = run(Array(repeating: 60, count: 240), inertia: &inertia)
        // The largest kick in one frame is a small part of a slow window speed.
        #expect(changes.map(abs).max()! < 8)
    }

    @Test func jitteredSamplesAreSmoothed() {
        var inertia = WindowInertia()
        // The same 300 points per second, but the window moves only on every second frame.
        let speeds = (0..<240).map { $0.isMultiple(of: 2) ? 600.0 : 0.0 }
        let changes = run(speeds, inertia: &inertia)
        // The raw samples jump by 600 each frame. The smoothed change stays far below that.
        #expect(changes.suffix(120).map(abs).max()! < 45)
        #expect(abs(changes.reduce(0, +) + 300) < 40)
    }

    @Test func windowSnapIsIgnored() {
        var inertia = WindowInertia()
        _ = inertia.velocityChange(origin: .zero, time: 0)
        let change = inertia.velocityChange(origin: CGPoint(x: 900, y: 0), time: frame)
        #expect(change == .zero)
    }
}
