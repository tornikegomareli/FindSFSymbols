import SpriteKit

/// The holographic sticker effects: a foil sheen on hover, and a flip on copy.
/// To switch them off, set `isEnabled` to false. The scene then uses its plain copy pulse.
/// To remove them, delete this file and the three `holo` lines in SymbolScene.
@MainActor
final class HoloSticker {
    static let isEnabled = true
    /// `.sticker` is the foil of the Sticker library. `.rainbow` is the first foil. Change this to go back.
    static let style = Style.sticker

    enum Style {
        case sticker, rainbow
    }

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
        hoverShader.uniformNamed("u_size")?.vectorFloat2Value = vector_float2(Float(node.size.width), Float(node.size.height))
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

    static func makeShader() -> SKShader {
        let shader = SKShader(source: style == .sticker ? stickerSource : rainbowSource)
        // `u_size` is the sprite size in points. The built-in `u_sprite_size` is zero in some renders.
        shader.uniforms = [
            SKUniform(name: "u_tilt", vectorFloat2: vector_float2(0, 0)),
            SKUniform(name: "u_size", vectorFloat2: vector_float2(45, 45)),
        ]
        return shader
    }

    /// Rainbow bands plus a narrow bright glint. Both move with `u_tilt` and with time.
    /// The texture has premultiplied alpha, so every added color is multiplied by the alpha.
    private static let rainbowSource = """
    void main() {
        vec4 base = texture2D(u_texture, v_tex_coord);
        vec2 uv = v_tex_coord;
        float band = uv.x * 1.3 + uv.y * 0.9 + u_tilt.x * 1.6 + u_tilt.y * 1.1 + u_time * 0.15;
        vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (band + vec3(0.0, 0.33, 0.67)));
        float glint = pow(max(0.0, sin((uv.x - uv.y + u_tilt.x * 2.2 + u_time * 0.5) * 5.0)), 10.0);
        float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
        vec3 foil = mix(base.rgb, rainbow * base.a, 0.6) + rainbow * luma * 0.25;
        gl_FragColor = vec4(foil + glint * 0.75 * base.a, base.a);
    }
    """

    /// A port of FoilShader.metal and ReflectionShader.metal from https://github.com/bpisano/Sticker
    /// (MIT License, Copyright (c) 2024 bpisano). The math is the same: a white light at the pointer,
    /// then a pastel metal color that shifts with the tilt, then a diamond pattern and a noise that
    /// raise the contrast. `u_tilt` is the pointer offset from the center, from -0.5 to 0.5.
    /// One step differs: the foil tints the symbol color and does not replace it.
    /// The constants are the defaults of the library, but three are tuned for a 45 point symbol:
    /// BASELINE (library 0.3), CHECKER (library 5) and NOISE (library 100).
    private static let stickerSource = """
    #define SCALE 3.0
    #define INTENSITY 0.8
    #define BASELINE 0.5
    #define CONTRAST 0.9
    #define CHECKER 3.0
    #define CHECKER_INTENSITY 1.2
    #define NOISE 40.0
    #define NOISE_INTENSITY 1.2
    #define LIGHT 0.3

    float rnd(vec2 p) {
        return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    }

    float valueNoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float a = rnd(i);
        float b = rnd(i + vec2(1.0, 0.0));
        float c = rnd(i + vec2(0.0, 1.0));
        float d = rnd(i + vec2(1.0, 1.0));
        vec2 u = smoothstep(0.0, 1.0, f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    float luma(vec3 c) {
        return dot(c, vec3(0.299, 0.587, 0.114));
    }

    float diamonds(vec2 p, float scale) {
        p *= scale;
        vec2 r = vec2(p.x - p.y, p.x + p.y) * 0.70710678;
        return mod(floor(r.x) + floor(r.y), 2.0);
    }

    vec3 raiseContrast(vec3 c, float pattern, float amount) {
        float factor = mix(1.0, amount, pattern * luma(c));
        return (c - 0.5) * factor + 0.5;
    }

    void main() {
        vec4 tex = texture2D(u_texture, v_tex_coord);
        // The texture has premultiplied alpha. The library works on the plain color.
        // SpriteKit turns main into a Metal function with a result, so an early return does not compile.
        vec3 color = tex.rgb / max(tex.a, 0.004);
        vec2 pixel = v_tex_coord * u_size;

        float light = 1.0 - smoothstep(0.0, 0.5, distance(v_tex_coord, u_tilt + 0.5));
        color = mix(color, vec3(1.0), LIGHT * light);

        vec2 uv = (v_tex_coord + 2.5 - 1.5 * u_tilt) / SCALE;
        float grain = rnd(pixel) * 0.1;
        float aspect = u_size.x / u_size.y;
        float pattern = diamonds(vec2(v_tex_coord.x * aspect, v_tex_coord.y) * CHECKER, CHECKER);
        float noise = valueNoise(v_tex_coord * NOISE);

        vec3 foil = vec3(
            CONTRAST + 0.25 * sin(uv.x * 10.0 + grain),
            CONTRAST + 0.25 * cos(uv.y * 10.0 + grain),
            CONTRAST + 0.25 * sin((uv.x + uv.y) * 10.0 - grain));
        float amount = max(smoothstep(0.2, 1.0, luma(color)) * INTENSITY, BASELINE);
        // The library replaces the color with the pastel foil, which washes out a colored symbol.
        // Here the foil tints the color of the symbol, so the symbol keeps its hue.
        color = color * mix(vec3(1.0), foil / CONTRAST, amount) + (foil - CONTRAST) * 0.3 * amount;
        color = raiseContrast(color, pattern, CHECKER_INTENSITY);
        color = raiseContrast(color, noise, NOISE_INTENSITY);
        gl_FragColor = vec4(clamp(color, 0.0, 1.0) * tex.a, tex.a);
    }
    """
}
