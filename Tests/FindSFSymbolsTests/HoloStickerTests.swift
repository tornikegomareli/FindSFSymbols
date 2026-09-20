import AppKit
import SpriteKit
import Testing
@testable import FindSFSymbols

@MainActor
@Suite struct HoloStickerTests {
    /// Renders a one-color sprite off screen and returns the color of its center pixel.
    private func centerPixel(color: NSColor, shader: SKShader?) throws -> [Double] {
        let image = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.shader = shader
        let rendered = try #require(SKView(frame: NSRect(x: 0, y: 0, width: 64, height: 64)).texture(from: sprite))
        let cgImage = rendered.cgImage()
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        context.draw(cgImage, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        return pixel.prefix(3).map { Double($0) / 255 }
    }

    @Test(arguments: [
        [0.15, 0.35, 0.95],  // blue
        [0.90, 0.20, 0.20],  // red
        [0.20, 0.75, 0.35],  // green
    ])
    func foilKeepsTheSymbolColor(rgb: [Double]) throws {
        let color = NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
        let shader = HoloSticker.makeShader()
        // The pointer light sits in a corner, away from the center pixel.
        shader.uniformNamed("u_tilt")?.vectorFloat2Value = vector_float2(0.5, 0.5)
        let plain = try centerPixel(color: color, shader: nil)
        let foiled = try centerPixel(color: color, shader: shader)

        // A shader that does not compile draws the plain sprite. A difference proves that it runs.
        let difference = zip(plain, foiled).map { abs($0 - $1) }
        #expect(difference.max()! > 0.01, "The foil did not render. plain \(plain), foiled \(foiled)")
        // The strongest channel stays the strongest, and no channel moves far.
        #expect(foiled.firstIndex(of: foiled.max()!) == plain.firstIndex(of: plain.max()!))
        #expect(difference.max()! < 0.3, "The foil washed out the color. plain \(plain), foiled \(foiled)")
    }
}
