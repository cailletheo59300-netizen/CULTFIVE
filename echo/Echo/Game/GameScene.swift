import SpriteKit
import UIKit
import EchoCore

/// Dessine la partie avec SpriteKit et transmet les gestes du doigt au moteur.
/// La logique avance par pas fixes de 1/60 s (même sur un écran 120 Hz) : les fantômes rejouent exactement la manche.
/// L'arène (1000 × 1600 unités) est centrée et mise à l'échelle de l'écran, sans déformation. Le décor animé remplit
/// tout l'écran derrière elle.
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
    private var decor: DecorLayer?
    private var lastTime: TimeInterval?
    private var accumulator: TimeInterval = 0

    // Doigt
    private var trackedTouch: UITouch?
    private var lastTouchPoint: CGPoint?
    private var lastTouchTime: TimeInterval = 0
    /// Vitesse du doigt lissée (unités d'arène par seconde) : l'accélération reste stable d'un geste à l'autre.
    private var smoothedSpeed: Double = 0

    // Nœuds
    private let trail: TrailRenderer
    private var ghostNodes: [Int: GhostNode] = [:]
    private let orb = SKNode()
    private let nextOrb = SKShapeNode(circleOfRadius: 40)
    private var lastPhase: GamePhase = .ready

    private static let ghostTrailLength = 9
    /// Place gardée en haut de l'écran pour le score (points SwiftUI).
    private static let topInset: CGFloat = 96
    private static let bottomInset: CGFloat = 28

    init(engine: GameEngine, theme: GameTheme, controlSetting: Double) {
        self.engine = engine
        self.theme = theme
        self.controlSetting = controlSetting
        trail = TrailRenderer(skin: theme.trail, theme: theme, radius: engine.tuning.playerRadius)
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
        guard arena.parent != nil else { return }
        layoutArena()
    }

    private func buildArena() {
        let size = engine.tuning.arena
        let border = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.x, height: size.y), cornerRadius: 48)
        border.strokeColor = theme.borderColor.withAlphaComponent(0.85)
        border.lineWidth = 5
        // Voile léger sous l'arène : le décor reste visible mais ne gêne pas la lecture.
        border.fillColor = theme.isLight ? UIColor.white.withAlphaComponent(0.25) : UIColor.black.withAlphaComponent(0.22)
        border.zPosition = 0
        arena.addChild(border)

        // Orbe à attraper : halo + cœur qui pulse. Orbe suivant : simple cercle discret.
        let halo = sprite(Textures.glow, size: 230, color: theme.orbColor, alpha: theme.isLight ? 0.3 : 0.55)
        halo.blendMode = theme.glowBlend
        let core = sprite(Textures.disc, size: 2 * engine.tuning.orbRadius, color: theme.orbColor, alpha: 1)
        orb.addChild(halo)
        orb.addChild(core)
        orb.zPosition = 10
        orb.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 0.94, duration: 0.45)])))
        arena.addChild(orb)

        nextOrb.strokeColor = theme.orbColor.withAlphaComponent(0.4)
        nextOrb.lineWidth = 5
        nextOrb.zPosition = 9
        arena.addChild(nextOrb)

        trail.node.zPosition = 20
        arena.addChild(trail.node)

        effects.zPosition = 40
        arena.addChild(effects)
    }

    /// Centre l'arène sous le score et l'agrandit au maximum sans la déformer ; redessine le décor à la taille de l'écran.
    private func layoutArena() {
        let size = engine.tuning.arena
        let available = CGSize(width: self.size.width - 24, height: self.size.height - Self.topInset - Self.bottomInset)
        guard available.width > 0, available.height > 0 else { return }
        let scale = min(available.width / size.x, available.height / size.y)
        arena.setScale(scale)
        arena.position = CGPoint(x: (self.size.width - size.x * scale) / 2,
                                 y: Self.bottomInset + (available.height - size.y * scale) / 2)
        decor?.removeFromParent()
        let layer = DecorLayer(decor: theme.decor, size: self.size)
        layer.zPosition = -10
        addChild(layer)
        decor = layer
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
        smoothedSpeed = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        // Tous les points captés par l'écran depuis la dernière fois (jusqu'à 240 par seconde), pas seulement le dernier.
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in samples { move(to: sample.location(in: arena), at: sample.timestamp) }
    }

    private func move(to point: CGPoint, at time: TimeInterval) {
        guard let last = lastTouchPoint else { return }
        let delta = Vec2(Double(point.x - last.x), Double(point.y - last.y))
        let interval = min(0.1, max(1.0 / 480, time - lastTouchTime))
        lastTouchPoint = point
        lastTouchTime = time
        // Vitesse lissée sur ~40 ms : une mesure isolée qui « saute » ne change pas brusquement l'accélération.
        let instant = delta.length / interval
        let blend = 1 - exp(-interval / 0.04)
        smoothedSpeed += (instant - smoothedSpeed) * blend
        guard running else { return }
        let gain = engine.tuning.pointerGain(speed: smoothedSpeed, setting: controlSetting)
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
        let dt = CGFloat(min(currentTime - (lastTime ?? currentTime), 0.1))
        defer { lastTime = currentTime }
        var events: [GameEvent] = []
        if AppModel.captureAutopilot, running { autopilot() }
        if running, lastTime != nil {
            // Au plus 0,1 s rattrapée d'un coup (retour d'arrière-plan, ralentissement).
            accumulator += Double(dt)
            let step = 1.0 / Double(engine.tuning.ticksPerSecond)
            while accumulator >= step {
                events += engine.step()
                accumulator -= step
            }
        }
        handle(events)
        render(time: currentTime, dt: dt)
        onFrame?(events)
    }

    /// Captures : va vers l'orbe en contournant grossièrement les fantômes.
    private func autopilot() {
        guard let orb = engine.currentOrb else { return }
        var direction = orb - engine.player
        for ghost in engine.ghosts where !engine.isFading(ghost) {
            let away = engine.player - engine.position(of: ghost)
            let distance = max(1, away.length)
            if distance < 160 { direction += away * (160 / distance) }
        }
        engine.addInput(direction.limited(to: 14))
    }

    /// Après « Continuer » : la manche repart du centre.
    func restartAfterContinue() {
        trail.reset()
        accumulator = 0
    }

    // MARK: Dessin

    private func render(time: TimeInterval, dt: CGFloat) {
        if engine.phase != lastPhase {
            if engine.phase == .ready { trail.reset() }
            lastPhase = engine.phase
        }
        let dead = engine.isDead
        decor?.update(time: time, dt: dt)
        // Le point est dessiné avec le geste déjà reçu : il paraît collé au doigt.
        trail.update(position: point(engine.displayPlayer), time: time, dt: dt, visible: !dead)

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
        let halo = sprite(Textures.glow, size: 120, color: theme.ghostColor, alpha: theme.isLight ? 0.25 : 0.6)
        halo.blendMode = theme.glowBlend
        let core = sprite(Textures.disc, size: 2 * engine.tuning.ghostRadius, color: theme.ghostColor, alpha: 0.95)
        head.addChild(halo)
        head.addChild(core)
        // Anneau pointillé : signe qu'un fantôme pâle peut être absorbé.
        let prey = SKShapeNode(circleOfRadius: engine.tuning.ghostRadius + 14)
        prey.path = prey.path.map { $0.copy(dashingWithPhase: 0, lengths: [10, 8]) }
        prey.strokeColor = theme.isLight ? UIColor(hex: "#1C1A17") : .white
        prey.lineWidth = 4
        prey.isHidden = true
        prey.run(.repeatForever(.rotate(byAngle: .pi, duration: 1.5)))
        head.addChild(prey)
        head.zPosition = 15
        arena.addChild(head)
        var trail: [SKSpriteNode] = []
        for _ in 0..<Self.ghostTrailLength {
            let dot = sprite(Textures.glow, size: 50, color: theme.ghostColor, alpha: 0)
            dot.blendMode = theme.glowBlend
            dot.zPosition = 14
            arena.addChild(dot)
            trail.append(dot)
        }
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
                burstRing(at: trail.head.position, color: theme.orbColor)
            case .nearMiss(_, let multiplier):
                burstRing(at: trail.head.position, color: theme.playerColor, radius: 60 + CGFloat(multiplier) * 10)
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
        ring.glowWidth = theme.isLight ? 0 : 4
        ring.position = position
        effects.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.6, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    /// Absorption : un anneau se referme sur le joueur, qui grossit un instant.
    private func absorbEffect() {
        let ring = SKShapeNode(circleOfRadius: 140)
        ring.strokeColor = theme.ghostColor
        ring.lineWidth = 8
        ring.glowWidth = theme.isLight ? 0 : 6
        ring.position = trail.head.position
        effects.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 0.15, duration: 0.25), .fadeAlpha(to: 0.2, duration: 0.25)]), .removeFromParent()]))
        trail.head.run(.sequence([.scale(to: 1.5, duration: 0.12), .scale(to: 1, duration: 0.18)]))
        burstRing(at: trail.head.position, color: theme.orbColor, radius: 40)
    }

    private func flashBorder() {
        let size = engine.tuning.arena
        let flash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.x, height: size.y), cornerRadius: 48)
        flash.strokeColor = theme.orbColor
        flash.lineWidth = 10
        flash.glowWidth = theme.isLight ? 0 : 8
        effects.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    private func explode() {
        let origin = trail.head.position
        for i in 0..<18 {
            let angle = CGFloat(i) / 18 * 2 * .pi
            let dot = sprite(Textures.glow, size: 46, color: i.isMultiple(of: 2) ? theme.playerColor : theme.ghostColor, alpha: 1)
            dot.blendMode = theme.glowBlend
            dot.position = origin
            effects.addChild(dot)
            let distance = CGFloat.random(in: 120...260)
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.6)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, .fadeOut(withDuration: 0.6), .scale(to: 0.2, duration: 0.6)]), .removeFromParent()]))
        }
        trail.head.run(.group([.scale(to: 2.2, duration: 0.25), .fadeOut(withDuration: 0.25)]))
        trail.clearParticles()
        // L'arène tremble un court instant.
        let base = arena.position
        var steps: [SKAction] = (0..<6).map { i in
            SKAction.move(to: CGPoint(x: base.x + (i.isMultiple(of: 2) ? 7 : -7), y: base.y + CGFloat.random(in: -5...5)),
                          duration: 0.035)
        }
        steps.append(SKAction.move(to: base, duration: 0.035))
        arena.run(SKAction.sequence(steps))
    }
}

private struct GhostNode {
    let head: SKNode
    let trail: [SKSpriteNode]
    let prey: SKShapeNode

    /// Le fantôme s'efface (fin de vie, absorption ou « Continuer ») : fondu puis retrait.
    func fadeOutAndRemove() {
        let vanish = SKAction.sequence([.group([.fadeOut(withDuration: 0.5), .scale(to: 1.6, duration: 0.5)]), .removeFromParent()])
        head.run(vanish)
        trail.forEach { $0.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()])) }
    }
}
