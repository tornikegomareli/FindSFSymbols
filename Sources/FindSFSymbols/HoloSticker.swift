import SpriteKit

/// The holographic sticker effects: a foil sheen on hover, and a flip on copy.
/// To switch them off, set `isEnabled` to false. The scene then uses its plain copy pulse.
/// To remove them, delete this file and the three `holo` lines in SymbolScene.
@MainActor
final class HoloSticker {
    static let isEnabled = true

    private let hoverShader = HoloSticker.makeShader()
    private weak var hovered: SKSpriteNode?

    /// Puts the foil on the symbol under the pointer. The colors shift as the pointer moves over it.
    func hover(_ node: SKSpriteNode?, pointer: CGPoint?) {
        if hovered !== node {
            hovered?.shader = nil
            node?.shader = hoverShader
            hovered = node
        }
        guard let node, let pointer else { return }
        let tilt = vector_float2(
            Float((pointer.x - node.position.x) / max(1, node.size.width)),
            Float((pointer.y - node.position.y) / max(1, node.size.height)))
        hoverShader.uniformNamed("u_tilt")?.vectorFloat2Value = tilt
    }

    /// A copy of the symbol grows, turns one full time around its vertical axis, and shows "Copied".
    /// The copy has the original colors and no foil.
    /// The real symbol hides for that time, so its physics body is not touched.
    func playCopy(on node: SKSpriteNode, in scene: SKScene) {
        let duration = 0.7
        let copy = SKSpriteNode(texture: node.texture, size: node.size)
        copy.zRotation = node.zRotation
        let turn = SKTransformNode()
        turn.position = node.position
        turn.zPosition = 50
        turn.setScale(node.xScale)
        turn.addChild(copy)
        scene.addChild(turn)

        let baseScale = node.xScale
        node.alpha = 0
        turn.run(.sequence([
            .customAction(withDuration: duration) { [weak node] turnNode, elapsed in
                guard let turn = turnNode as? SKTransformNode else { return }
                let t = Double(elapsed) / duration
                let eased = t * t * (3 - 2 * t)
                turn.yRotation = eased * 2 * .pi
                turn.setScale(baseScale * (1 + 0.7 * sin(t * .pi)))
                if let node { turn.position = node.position }
            },
            .run { [weak node] in node?.alpha = 1 },
            .removeFromParent(),
        ]))

        let tag = SKLabelNode(fontNamed: "Menlo-Bold")
        tag.text = "Copied"
        tag.fontSize = 12
        tag.fontColor = .black
        tag.position = CGPoint(x: node.position.x, y: node.position.y + node.frame.height / 2 + 26)
        tag.zPosition = 60
        tag.alpha = 0
        scene.addChild(tag)
        tag.run(.sequence([
            .wait(forDuration: duration * 0.6),
            .group([.fadeIn(withDuration: 0.12), .moveBy(x: 0, y: 10, duration: 0.25)]),
            .wait(forDuration: 0.35),
            .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 14, duration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// Rainbow bands plus a narrow bright glint. Both move with `u_tilt` and with time.
    /// The foil tints the color of the symbol and does not replace it, so the symbol keeps its hue.
    /// The texture has premultiplied alpha, so every added color is multiplied by the alpha.
    static func makeShader() -> SKShader {
        let shader = SKShader(source: """
        void main() {
            vec4 base = texture2D(u_texture, v_tex_coord);
            vec2 uv = v_tex_coord;
            float band = uv.x * 1.3 + uv.y * 0.9 + u_tilt.x * 1.6 + u_tilt.y * 1.1 + u_time * 0.15;
            vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (band + vec3(0.0, 0.33, 0.67)));
            float glint = pow(max(0.0, sin((uv.x - uv.y + u_tilt.x * 2.2 + u_time * 0.5) * 5.0)), 10.0);
            vec3 tinted = base.rgb * (0.8 + 0.45 * rainbow) + rainbow * base.a * 0.12;
            gl_FragColor = vec4(min(tinted + glint * 0.5 * base.a, vec3(base.a)), base.a);
        }
        """)
        shader.uniforms = [SKUniform(name: "u_tilt", vectorFloat2: vector_float2(0, 0))]
        return shader
    }
}
