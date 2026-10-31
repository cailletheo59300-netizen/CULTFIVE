import SpriteKit
import UIKit
import EchoCore

/// Dessine la partie avec SpriteKit et transmet les gestes du doigt au moteur.
/// La logique avance par pas fixes de 1/60 s (même sur un écran 120 Hz) : les fantômes rejouent exactement la manche.
/// L'arène (1000 × 1600 unités) est centrée et mise à l'échelle de l'écran, sans déformation.
final class GameScene: SKScene {
    let engine: GameEngine
    private let theme: GameTheme
    /// Réglage du doigt, de 0 (« Précis ») à 1 (« Rapide »).
    private let controlSetting: Double
    /// Appelé après chaque image avec les événements de la logique (sons, HUD).
    var onFrame: (([GameEvent]) -> Void)?
    /// Faux pendant la pause : la logique ne tourne plus, les gestes sont ignorés.
    var running = true

    private let arena = SKNode()
    private let effects = SKNode()
    private var lastTime: TimeInterval?
    private var accumulator: TimeInterval = 0
    private var trackedTouch: UITouch?
    private var lastTouchPoint: CGPoint?
    private var lastTouchTime: TimeInterval = 0

    // Nœuds
    private let player = SKNode()
    private var playerTrail: [SKSpriteNode] = []
    private var trailHistory: [Vec2] = []
    private var ghostNodes: [Int: GhostNode] = [:]
    private let orb = SKNode()
    private let nextOrb = SKShapeNode(circleOfRadius: 40)
    private var lastPhase: GamePhase = .ready

    private static let trailLength = 16
    private static let ghostTrailLength = 9
    /// Place gardée en haut de l'écran pour le score (points SwiftUI).
    private static let topInset: CGFloat = 96
    private static let bottomInset: CGFloat = 28

    init(engine: GameEngine, theme: GameTheme, controlSetting: Double) {
        self.engine = engine
        self.theme = theme
        self.controlSetting = controlSetting
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    // MARK: Mise en place

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        guard arena.parent == nil else { return }
        addChild(arena)
        buildArena()
        layoutArena()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutArena()
    }

    private func buildArena() {
        let size = engine.tuning.arena
        let border = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.x, height: size.y), cornerRadius: 48)
        border.strokeColor = theme.borderColor.withAlphaComponent(0.8)
        border.lineWidth = 5
        border.fillColor = UIColor.white.withAlphaComponent(0.02)
        border.zPosition = 0
        arena.addChild(border)

        // Orbe à attraper : halo + cœur qui pulse. Orbe suivant : simple cercle discret.
        let halo = sprite(Textures.glow, size: 230, color: theme.orbColor, alpha: 0.55)
        halo.blendMode = .add
        let core = sprite(Textures.disc, size: 2 * engine.tuning.orbRadius, color: theme.orbColor, alpha: 1)
        orb.addChild(halo)
        orb.addChild(core)
        orb.zPosition = 10
        orb.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 0.94, duration: 0.45)])))
        arena.addChild(orb)

        nextOrb.strokeColor = theme.orbColor.withAlphaComponent(0.35)
        nextOrb.lineWidth = 5
        nextOrb.zPosition = 9
        arena.addChild(nextOrb)

        // Joueur : traînée, halo, cœur.
        for _ in 0..<Self.trailLength {
            let dot = sprite(Textures.glow, size: 60, color: theme.playerColor, alpha: 0)
            dot.blendMode = .add
            dot.zPosition = 20
            arena.addChild(dot)
            playerTrail.append(dot)
        }
        let playerHalo = sprite(Textures.glow, size: 150, color: theme.playerColor, alpha: 0.6)
        playerHalo.blendMode = .add
        let playerCore = sprite(Textures.disc, size: 2 * engine.tuning.playerRadius, color: .white, alpha: 1)
        player.addChild(playerHalo)
        player.addChild(playerCore)
        player.zPosition = 30
        arena.addChild(player)

        effects.zPosition = 40
        arena.addChild(effects)
    }

    /// Centre l'arène sous le score et l'agrandit au maximum sans la déformer.
    private func layoutArena() {
        let size = engine.tuning.arena
        let available = CGSize(width: self.size.width - 24, height: self.size.height - Self.topInset - Self.bottomInset)
        guard available.width > 0, available.height > 0 else { return }
        let scale = min(available.width / size.x, available.height / size.y)
        arena.setScale(scale)
        arena.position = CGPoint(x: (self.size.width - size.x * scale) / 2,
                                 y: Self.bottomInset + (available.height - size.y * scale) / 2)
    }

    private func sprite(_ texture: SKTexture, size: CGFloat, color: UIColor, alpha: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
        node.color = color
        node.colorBlendFactor = 1
        node.alpha = alpha
        return node
    }

    // MARK: Gestes

    // Le point suit le mouvement du doigt (et non sa position) : le doigt ne cache jamais le point, et on peut jouer
    // n'importe où sur l'écran. Accélération douce : doigt lent = précis, doigt rapide = le point va plus loin.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch
        lastTouchPoint = touch.location(in: arena)
        lastTouchTime = touch.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch), let last = lastTouchPoint else { return }
        let point = touch.location(in: arena)
        let delta = Vec2(Double(point.x - last.x), Double(point.y - last.y))
        // Vitesse du doigt en unités d'arène par seconde (intervalle borné : 120 Hz au plus, 0,1 s au moins).
        let interval = min(0.1, max(1.0 / 240, touch.timestamp - lastTouchTime))
        lastTouchPoint = point
        lastTouchTime = touch.timestamp
        guard running else { return }
        let gain = engine.tuning.pointerGain(speed: delta.length / interval, setting: controlSetting)
        engine.addInput(delta * gain)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = trackedTouch, touches.contains(touch) {
            trackedTouch = nil
            lastTouchPoint = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: Boucle

    override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        var events: [GameEvent] = []
        if running, let last = lastTime {
            // Au plus 0,1 s rattrapée d'un coup (retour d'arrière-plan, ralentissement).
            accumulator += min(currentTime - last, 0.1)
            let step = 1.0 / Double(engine.tuning.ticksPerSecond)
            while accumulator >= step {
                events += engine.step()
                accumulator -= step
            }
        }
        handle(events)
        render(time: currentTime)
        onFrame?(events)
    }

    /// Après « Continuer » : la manche repart du centre.
    func restartAfterContinue() {
        player.alpha = 1
        player.setScale(1)
        trailHistory = []
        accumulator = 0
    }

    // MARK: Dessin

    private func render(time: TimeInterval) {
        if engine.phase != lastPhase {
            if engine.phase == .ready { trailHistory = [] }
            lastPhase = engine.phase
        }
        let dead = engine.isDead

        // Joueur et sa traînée.
        player.position = point(engine.player)
        if !dead, trailHistory.last != engine.player {
            trailHistory.append(engine.player)
            if trailHistory.count > Self.trailLength { trailHistory.removeFirst() }
        }
        for (i, dot) in playerTrail.enumerated() {
            // i = 0 : le bout de la traînée ; le dernier : juste derrière le point.
            let historyIndex = trailHistory.count - Self.trailLength + i
            guard historyIndex >= 0, !dead else {
                dot.alpha = 0
                continue
            }
            let k = CGFloat(i + 1) / CGFloat(Self.trailLength)
            dot.position = point(trailHistory[historyIndex])
            dot.alpha = 0.75 * k
            dot.setScale(0.35 + 0.65 * k)
            dot.color = theme.trailColor(at: Double(1 - k), time: time)
        }

        // Orbes.
        if let current = engine.currentOrb, !dead {
            orb.isHidden = false
            orb.position = point(current)
        } else {
            orb.isHidden = true
        }
        if let next = engine.nextOrb, !dead {
            nextOrb.isHidden = false
            nextOrb.position = point(next)
        } else {
            nextOrb.isHidden = true
        }

        renderGhosts()
    }

    private func renderGhosts() {
        let alive = Set(engine.ghosts.map(\.round))
        for (round, node) in ghostNodes where !alive.contains(round) {
            node.fadeOutAndRemove()
            ghostNodes[round] = nil
        }
        // Avant le premier geste, les fantômes attendent au centre, à peine visibles.
        let waiting = engine.phase == .ready
        let armed = engine.ghostsArmed && !waiting
        for ghost in engine.ghosts {
            let node = ghostNodes[ghost.round] ?? makeGhostNode(ghost.round)
            // Dernière manche du fantôme : il pâlit et palpite. Il est inoffensif et peut être absorbé.
            let fading = engine.isFading(ghost)
            let pulse = CGFloat(sin(CACurrentMediaTime() * 7))
            let fade: CGFloat = fading ? 0.5 + 0.15 * pulse : 1
            node.head.position = point(engine.position(of: ghost))
            node.head.alpha = (waiting ? 0.25 : (armed ? 1 : 0.4)) * fade
            node.head.setScale(fading ? 1.05 + 0.1 * pulse : 1)
            node.prey.isHidden = !fading || waiting
            for (i, dot) in node.trail.enumerated() {
                let back = (Self.ghostTrailLength - i) * 2
                let k = CGFloat(i + 1) / CGFloat(Self.ghostTrailLength)
                dot.position = point(engine.position(of: ghost, atTick: max(0, engine.tick - back)))
                dot.alpha = waiting ? 0 : (armed ? 0.55 : 0.2) * k * fade
                dot.setScale(0.3 + 0.7 * k)
            }
        }
    }

    private func makeGhostNode(_ round: Int) -> GhostNode {
        let head = SKNode()
        let halo = sprite(Textures.glow, size: 120, color: theme.ghostColor, alpha: 0.6)
        halo.blendMode = .add
        let core = sprite(Textures.disc, size: 2 * engine.tuning.ghostRadius, color: theme.ghostColor, alpha: 0.95)
        head.addChild(halo)
        head.addChild(core)
        // Anneau blanc pointillé : signe qu'un fantôme pâle peut être absorbé.
        let prey = SKShapeNode(circleOfRadius: engine.tuning.ghostRadius + 14)
        let dashes = prey.path.map { $0.copy(dashingWithPhase: 0, lengths: [10, 8]) }
        prey.path = dashes
        prey.strokeColor = .white
        prey.lineWidth = 4
        prey.isHidden = true
        prey.run(.repeatForever(.rotate(byAngle: .pi, duration: 1.5)))
        head.addChild(prey)
        head.zPosition = 15
        arena.addChild(head)
        var trail: [SKSpriteNode] = []
        for _ in 0..<Self.ghostTrailLength {
            let dot = sprite(Textures.glow, size: 50, color: theme.ghostColor, alpha: 0)
            dot.blendMode = .add
            dot.zPosition = 14
            arena.addChild(dot)
            trail.append(dot)
        }
        // Apparition : le nouveau fantôme grossit depuis le centre.
        head.setScale(0.1)
        head.run(.scale(to: 1, duration: 0.35))
        let node = GhostNode(head: head, trail: trail, prey: prey)
        ghostNodes[round] = node
        return node
    }

    private func point(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    // MARK: Effets

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .orbCollected:
                burstRing(at: player.position, color: theme.orbColor)
            case .nearMiss(_, let multiplier):
                burstRing(at: player.position, color: theme.playerColor, radius: 60 + CGFloat(multiplier) * 10)
            case .roundCleared:
                flashBorder()
            case .died:
                explode()
            case .ghostAbsorbed:
                absorbEffect()
            case .roundStarted, .multiplierLost:
                break
            }
        }
    }

    private func burstRing(at position: CGPoint, color: UIColor, radius: CGFloat = 50) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color
        ring.lineWidth = 6
        ring.glowWidth = 4
        ring.position = position
        effects.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.6, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    /// Absorption : un anneau se referme sur le joueur, qui grossit un instant.
    private func absorbEffect() {
        let ring = SKShapeNode(circleOfRadius: 140)
        ring.strokeColor = theme.ghostColor
        ring.lineWidth = 8
        ring.glowWidth = 6
        ring.position = player.position
        effects.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 0.15, duration: 0.25), .fadeAlpha(to: 0.2, duration: 0.25)]), .removeFromParent()]))
        player.run(.sequence([.scale(to: 1.5, duration: 0.12), .scale(to: 1, duration: 0.18)]))
        burstRing(at: player.position, color: theme.orbColor, radius: 40)
    }

    private func flashBorder() {
        let size = engine.tuning.arena
        let flash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.x, height: size.y), cornerRadius: 48)
        flash.strokeColor = theme.orbColor
        flash.lineWidth = 10
        flash.glowWidth = 8
        effects.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    private func explode() {
        let origin = player.position
        for i in 0..<18 {
            let angle = CGFloat(i) / 18 * 2 * .pi
            let dot = sprite(Textures.glow, size: 46, color: i.isMultiple(of: 2) ? theme.playerColor : theme.ghostColor, alpha: 1)
            dot.blendMode = .add
            dot.position = origin
            effects.addChild(dot)
            let distance = CGFloat.random(in: 120...260)
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.6)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, .fadeOut(withDuration: 0.6), .scale(to: 0.2, duration: 0.6)]), .removeFromParent()]))
        }
        player.run(.group([.scale(to: 2.2, duration: 0.25), .fadeOut(withDuration: 0.25)]))
        // L'arène tremble un court instant.
        let base = arena.position
        var steps: [SKAction] = (0..<6).map { i in
            SKAction.move(to: CGPoint(x: base.x + (i.isMultiple(of: 2) ? 7 : -7), y: base.y + CGFloat.random(in: -5...5)),
                          duration: 0.035)
        }
        steps.append(SKAction.move(to: base, duration: 0.035))
        let shake = SKAction.sequence(steps)
        arena.run(shake)
    }
}

private struct GhostNode {
    let head: SKNode
    let trail: [SKSpriteNode]
    let prey: SKShapeNode

    /// Le fantôme s'efface (fin de vie ou « Continuer ») : fondu puis retrait.
    func fadeOutAndRemove() {
        let vanish = SKAction.sequence([.group([.fadeOut(withDuration: 0.5), .scale(to: 1.6, duration: 0.5)]), .removeFromParent()])
        head.run(vanish)
        trail.forEach { $0.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()])) }
    }
}

/// Textures dessinées une fois au lancement (aucune image à produire à la main).
enum Textures {
    /// Halo : blanc au centre, transparent au bord (teinté par la couleur du sprite).
    static let glow: SKTexture = make(size: 128) { context, rect in
        let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.35, 1])!
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: rect.width / 2, options: [])
    }

    /// Disque plein aux bords doux.
    static let disc: SKTexture = make(size: 128) { context, rect in
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
    }

    private static func make(size: CGFloat, draw: (CGContext, CGRect) -> Void) -> SKTexture {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let image = UIGraphicsImageRenderer(size: rect.size).image { draw($0.cgContext, rect) }
        return SKTexture(image: image)
    }
}
