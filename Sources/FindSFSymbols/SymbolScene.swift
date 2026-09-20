import AppKit
import SpriteKit
import SymbolSearch

/// The pile of symbols on the ground and the results that float under the search bar.
final class SymbolScene: SKScene {
    var onCopy: (String) -> Void = { _ in }
    var onMouseDown: () -> Void = {}
    /// The deployment target. A symbol that needs a later iOS turns gray and stays low.
    var minIOS: Double? {
        didSet {
            for (name, node) in nodes { node.texture = Self.texture(for: name, isAvailable: isAvailable(name)) }
            layoutSlots()
        }
    }

    private struct Slot {
        var target: CGPoint
        /// 0 is a sure match. 1 is a weak match, and it hangs loose.
        var looseness: Double
    }

    private var nodes: [String: SKSpriteNode] = [:]
    private var pileNames: Set<String> = []
    private var firstIOS: [String: Double] = [:]
    private var slots: [String: Slot] = [:]
    private var matches: [Match] = []
    private let hoverLabel = HoverLabel()
    private let holo = HoloSticker()
    private var pointer: CGPoint?
    private var drag: (node: SKSpriteNode, start: CGPoint, moved: Bool)?
    private var inertia = WindowInertia()
    private var windowDrag: (origin: CGPoint, mouse: CGPoint)?

    private enum Category {
        static let pile: UInt32 = 1
        static let floating: UInt32 = 2
        static let wall: UInt32 = 4
    }

    private static let pointSize: CGFloat = 40
    private static let slotSpacing: CGFloat = 76
    private static let palette: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint, .systemTeal,
        .systemBlue, .systemIndigo, .systemPurple, .systemPink, .systemBrown, .darkGray,
    ]

    override init() {
        super.init(size: CGSize(width: 1200, height: 720))
        scaleMode = .resizeFill
        backgroundColor = NSColor(red: 0.925, green: 0.925, blue: 0.937, alpha: 1)
        addChild(hoverLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        // A tracking area delivers mouseMoved while the search field has the keyboard focus.
        view.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: view))
        buildWalls()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildWalls()
        layoutSlots()
    }

    private func buildWalls() {
        // The walls extend above the window. Symbols fall in from there at launch.
        let body = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: size.width, height: size.height * 4))
        body.categoryBitMask = Category.wall
        body.friction = 0.8
        physicsBody = body
    }

    // MARK: - Pile

    func fillPile(with symbols: [Symbol]) {
        firstIOS = Dictionary(uniqueKeysWithValues: symbols.map { ($0.name, $0.ios) })
        // About 110 symbols in a 1200 point window give a low pile.
        let count = Int(size.width / 11)
        let objectCategories: Set<String> = [
            "Objects & Tools", "Nature", "Devices", "Transportation", "Home", "Fitness", "Gaming",
            "Health", "Weather", "Camera & Photos",
        ]
        let candidates = symbols.filter {
            $0.name.split(separator: ".").count <= 2 && !objectCategories.isDisjoint(with: $0.categories)
        }
        for symbol in candidates.shuffled().prefix(count) {
            let position = CGPoint(
                x: .random(in: 40...(size.width - 40)),
                y: .random(in: size.height * 0.6...size.height * 3))
            guard let node = makeNode(symbol.name, at: position) else { continue }
            node.zRotation = .random(in: -.pi ... .pi)
            pileNames.insert(symbol.name)
        }
    }

    private func isAvailable(_ name: String) -> Bool {
        guard let minIOS, let first = firstIOS[name] else { return true }
        return first <= minIOS
    }

    private func makeNode(_ name: String, at position: CGPoint) -> SKSpriteNode? {
        guard let texture = Self.texture(for: name, isAvailable: isAvailable(name)) else { return nil }
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: texture.size().width / 3, height: texture.size().height / 3)
        node.name = name
        node.position = position
        let body = SKPhysicsBody(circleOfRadius: max(node.size.width, node.size.height) * 0.42)
        body.restitution = 0.25
        body.friction = 0.6
        body.categoryBitMask = Category.pile
        body.collisionBitMask = Category.pile | Category.wall
        node.physicsBody = body
        addChild(node)
        nodes[name] = node
        return node
    }

    private static func texture(for name: String, isAvailable: Bool) -> SKTexture? {
        let hash = name.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize * 3, weight: .medium)
        if isAvailable {
            // Multicolor symbols keep their own colors. The others take one palette color.
            configuration = configuration
                .applying(.init(hierarchicalColor: palette[abs(hash) % palette.count]))
                .applying(.preferringMulticolor())
        } else {
            configuration = configuration.applying(.init(hierarchicalColor: NSColor(white: 0.72, alpha: 1)))
        }
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }
        return SKTexture(image: image)
    }

    // MARK: - Results

    /// Floats `matches` under the search bar, best match first. Every other symbol falls back.
    func show(_ matches: [Match]) {
        self.matches = matches
        layoutSlots()
    }

    private func layoutSlots() {
        let columns = max(3, min(10, Int((size.width - 160) / Self.slotSpacing)))
        let top = size.height - 235
        // The lowest row belongs to the symbols that the deployment target does not have.
        let lowRow: CGFloat = 310
        let rows = max(1, Int((top - lowRow - Self.slotSpacing) / Self.slotSpacing) + 1)
        let available = Array(matches.filter { isAvailable($0.symbol.name) }.prefix(columns * rows))
        let unavailable = Array(matches.filter { !isAvailable($0.symbol.name) }.prefix(columns))

        var newSlots: [String: Slot] = [:]
        func place(_ match: Match, index: Int, of count: Int, rowY: CGFloat, isAvailable: Bool) {
            let inRow = min(columns, count - (index / columns) * columns)
            let x = size.width / 2 + (CGFloat(index % columns) - CGFloat(inRow - 1) / 2) * Self.slotSpacing
            let name = match.symbol.name
            // A new result rises out of the ground below its slot.
            guard let node = nodes[name] ?? makeNode(name, at: CGPoint(x: x + .random(in: -60...60), y: -30))
            else { return }
            // A score of 0.5 is fully loose. A score of 1 is firm.
            let looseness = isAvailable ? min(1, max(0, (1 - match.score) * 2)) : 1
            newSlots[name] = Slot(target: CGPoint(x: x, y: rowY - 30 * looseness), looseness: looseness)
            lift(node, scale: isAvailable ? 1 + 0.35 * match.score : 0.85)
        }
        for (index, match) in available.enumerated() {
            let rowY = top - CGFloat(index / columns) * Self.slotSpacing
            place(match, index: index, of: available.count, rowY: rowY, isAvailable: true)
        }
        for (index, match) in unavailable.enumerated() {
            place(match, index: index, of: unavailable.count, rowY: lowRow, isAvailable: false)
        }
        for name in slots.keys where newSlots[name] == nil {
            if let node = nodes[name] { release(node) }
        }
        slots = newSlots
    }

    private func lift(_ node: SKSpriteNode, scale: Double) {
        node.removeAction(forKey: "expire")
        node.alpha = 1
        node.zPosition = 10
        node.run(.scale(to: scale, duration: 0.3))
        guard let body = node.physicsBody else { return }
        body.affectedByGravity = false
        body.categoryBitMask = Category.floating
        // A floating symbol passes through the pile and the walls.
        body.collisionBitMask = Category.floating
    }

    private func release(_ node: SKSpriteNode) {
        node.zPosition = 0
        node.run(.scale(to: 1, duration: 0.3))
        guard let body = node.physicsBody else { return }
        body.affectedByGravity = true
        body.categoryBitMask = Category.pile
        body.collisionBitMask = Category.pile | Category.wall
        body.angularVelocity = .random(in: -4...4)
        // A symbol that was not in the first pile leaves after a rest. This keeps the pile bounded.
        guard let name = node.name, !pileNames.contains(name) else { return }
        let expire = SKAction.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 0.4), .removeFromParent()])
        node.run(expire, withKey: "expire")
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        for (name, slot) in slots {
            guard let node = nodes[name], let body = node.physicsBody, node !== drag?.node else { continue }
            // Damped spring to the slot. A loose symbol has a soft spring, a large bob, and a wobble.
            let loose = slot.looseness
            let phase = Double(slot.target.x) * 0.05
            let bob = sin(currentTime * (1.4 + loose) + phase) * (3 + 15 * loose)
            let stiffness = 70 - 45 * loose
            let damping = 1.5 * stiffness.squareRoot()
            let dx = slot.target.x - node.position.x
            let dy = slot.target.y + bob - node.position.y
            body.applyForce(CGVector(
                dx: body.mass * (stiffness * dx - damping * body.velocity.dx),
                dy: body.mass * (stiffness * dy - damping * body.velocity.dy)))
            let tilt = sin(currentTime * 1.1 + phase) * 0.4 * loose
            body.angularVelocity = (tilt - node.zRotation) * 5
        }
        if let drag, drag.moved, let pointer, let body = drag.node.physicsBody {
            // The symbol chases the pointer. It keeps this velocity on release, so a flick throws it.
            let dx = (pointer.x - drag.node.position.x) * 18, dy = (pointer.y - drag.node.position.y) * 18
            let speed = max(1, hypot(dx, dy) / 3500)
            body.velocity = CGVector(dx: dx / speed, dy: dy / speed)
        }
        applyWindowInertia(at: currentTime)
        // The symbols move under a still pointer, so the label updates each frame.
        let hovered = pointer.flatMap(symbolNode(at:))
        hoverLabel.show(hovered, text: hovered?.name.map(label(for:)), in: size)
        // A dragged symbol keeps its plain look.
        if HoloSticker.isEnabled { holo.hover(drag == nil ? hovered : nil, pointer: pointer) }
        for (name, node) in nodes where node.parent == nil {
            nodes[name] = nil
        }
    }

    /// The symbols have inertia. They lag when the window speeds up and slide on when it stops.
    private func applyWindowInertia(at time: TimeInterval) {
        guard let origin = view?.window?.frame.origin else { return }
        let change = inertia.velocityChange(origin: origin, time: time)
        guard change != .zero else { return }
        for node in nodes.values where node !== drag?.node {
            guard let body = node.physicsBody else { continue }
            body.velocity = CGVector(dx: body.velocity.dx + change.dx, dy: body.velocity.dy + change.dy)
        }
    }

    private func label(for name: String) -> String {
        guard !isAvailable(name), let first = firstIOS[name] else { return name }
        let version = first == first.rounded() ? String(Int(first)) : String(first)
        return "\(name)  needs iOS \(version)"
    }

    // MARK: - Mouse

    private func symbolNode(at point: CGPoint) -> SKSpriteNode? {
        nodes(at: point)
            .compactMap { $0 as? SKSpriteNode }
            .filter { $0.name != nil }
            .max { $0.zPosition < $1.zPosition }
    }

    override func mouseMoved(with event: NSEvent) {
        pointer = event.location(in: self)
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown()
        let location = event.location(in: self)
        guard let node = symbolNode(at: location) else {
            // The scene covers the title bar, so a press on empty background moves the window.
            if let origin = view?.window?.frame.origin { windowDrag = (origin, NSEvent.mouseLocation) }
            return
        }
        drag = (node, location, false)
    }

    override func mouseDragged(with event: NSEvent) {
        if let windowDrag {
            let mouse = NSEvent.mouseLocation
            view?.window?.setFrameOrigin(CGPoint(
                x: windowDrag.origin.x + mouse.x - windowDrag.mouse.x,
                y: windowDrag.origin.y + mouse.y - windowDrag.mouse.y))
            return
        }
        let location = event.location(in: self)
        pointer = location
        if let start = drag?.start, hypot(location.x - start.x, location.y - start.y) > 5 {
            drag?.moved = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        // A press with no movement is a click. A press with movement is a throw.
        if let drag, !drag.moved { copy(drag.node) }
        drag = nil
        windowDrag = nil
    }

    private func copy(_ node: SKSpriteNode) {
        guard let name = node.name else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
        onCopy(name)
        if HoloSticker.isEnabled { return holo.playCopy(on: node, in: self) }

        let scale = node.xScale
        node.run(.sequence([.scale(to: scale * 1.35, duration: 0.08), .scale(to: scale, duration: 0.2)]))
        let ring = SKShapeNode(circleOfRadius: 26)
        ring.position = node.position
        ring.strokeColor = .systemBlue
        ring.lineWidth = 3
        ring.zPosition = 20
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }
}

/// The symbol name next to the pointer.
private final class HoverLabel: SKNode {
    private let label = SKLabelNode(fontNamed: "Menlo")
    private let background = SKShapeNode()

    override init() {
        super.init()
        zPosition = 100
        isHidden = true
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        background.fillColor = NSColor.black.withAlphaComponent(0.78)
        background.strokeColor = .clear
        addChild(background)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(_ node: SKSpriteNode?, text: String?, in sceneSize: CGSize) {
        guard let node, let text else {
            isHidden = true
            return
        }
        if label.text != text {
            label.text = text
            let frame = label.frame.insetBy(dx: -9, dy: -6)
            background.path = CGPath(
                roundedRect: CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height),
                cornerWidth: 7, cornerHeight: 7, transform: nil)
        }
        let halfWidth = label.frame.width / 2 + 12
        position = CGPoint(
            x: min(max(node.position.x, halfWidth), sceneSize.width - halfWidth),
            y: node.position.y + node.frame.height / 2 + 20)
        isHidden = false
    }
}
