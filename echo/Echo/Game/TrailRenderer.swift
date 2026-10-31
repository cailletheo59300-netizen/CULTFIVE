import SpriteKit
import UIKit
import EchoCore

/// Dessine le point du joueur et sa traînée selon l'apparence équipée (points, ruban, particules, éclairs…).
/// Utilisé en partie et dans les aperçus de la boutique. Les tailles sont en unités d'arène.
final class TrailRenderer {
    /// Tout ce qui est dessiné (traînée, particules, tête).
    let node = SKNode()
    /// Le point du joueur (explosion, absorption).
    let head = SKNode()

    private let skin: Skin
    private let theme: GameTheme
    private let radius: CGFloat
    private let length: Int
    private var dots: [SKSpriteNode] = []
    private var history: [CGPoint] = []
    private let particles = ParticleField()
    private var ribbonGlow: SKShapeNode?
    private var ribbonCore: SKShapeNode?
    private var bolt: SKShapeNode?
    private var boltTimer: CGFloat = 0
    private var emitCarry: CGFloat = 0
    private var idleCarry: CGFloat = 0
    private var lastPosition: CGPoint?
    private let halo: SKSpriteNode
    private let core: SKSpriteNode
    private var extra: SKSpriteNode?

    private var style: Skin.Style { skin.style }
    private var blend: SKBlendMode { theme.glowBlend }

    init(skin: Skin, theme: GameTheme, radius: CGFloat) {
        self.skin = skin
        self.theme = theme
        self.radius = radius
        length = skin.style == .comet ? 34 : 16
        halo = SKSpriteNode(texture: Textures.glow, size: CGSize(width: radius * 7, height: radius * 7))
        core = SKSpriteNode(texture: skin.style == .pixel ? Textures.square : Textures.disc,
                            size: CGSize(width: radius * 2, height: radius * 2))
        build()
    }

    private func build() {
        let colors = skin.colors.map { UIColor(hex: $0) }
        particles.zPosition = 1
        node.addChild(particles)

        if style == .neon {
            let glow = SKShapeNode()
            glow.lineWidth = radius * 0.9
            glow.glowWidth = radius * 0.6
            glow.lineCap = .round
            glow.lineJoin = .round
            glow.zPosition = 2
            let inner = SKShapeNode()
            inner.lineWidth = radius * 0.3
            inner.strokeColor = .white
            inner.lineCap = .round
            inner.lineJoin = .round
            inner.zPosition = 3
            node.addChild(glow)
            node.addChild(inner)
            ribbonGlow = glow
            ribbonCore = inner
        } else {
            let texture: SKTexture = switch style {
            case .pixel: Textures.square
            case .bubbles: Textures.bubble
            case .sakura: Textures.petal
            default: Textures.glow
            }
            for i in 0..<length {
                let dot = SKSpriteNode(texture: texture)
                let size: CGFloat = switch style {
                case .pixel: radius * 1.3
                case .bubbles, .sakura: radius * 1.5
                case .comet: radius * 3.4
                default: radius * 2.8
                }
                dot.size = CGSize(width: size, height: size)
                dot.colorBlendFactor = 1
                dot.blendMode = (style == .bubbles || style == .sakura || style == .pixel) && theme.isLight ? .alpha : blend
                dot.alpha = 0
                dot.zRotation = style == .sakura ? CGFloat(i) * 1.7 : 0
                dot.zPosition = 2
                node.addChild(dot)
                dots.append(dot)
            }
        }

        if style == .electric {
            let bolt = SKShapeNode()
            bolt.strokeColor = colors.last ?? .cyan
            bolt.lineWidth = radius * 0.22
            bolt.glowWidth = radius * 0.3
            bolt.zPosition = 4
            bolt.alpha = 0
            node.addChild(bolt)
            self.bolt = bolt
        }

        // Tête : halo + cœur, adaptés au style.
        halo.colorBlendFactor = 1
        halo.color = theme.playerColor
        halo.alpha = 0.6
        halo.blendMode = blend
        core.colorBlendFactor = 1
        core.color = theme.isLight ? UIColor(hex: "#1C1A17") : .white
        switch style {
        case .fire:
            core.color = UIColor(hex: "#FFF6C8")
            halo.color = UIColor(hex: "#FF7A1A")
            halo.size = CGSize(width: radius * 9, height: radius * 9)
        case .galaxy:
            let star = SKSpriteNode(texture: Textures.star, size: CGSize(width: radius * 5, height: radius * 5))
            star.color = UIColor(hex: "#E9DCFF")
            star.colorBlendFactor = 1
            star.blendMode = blend
            star.zPosition = 1
            star.run(.repeatForever(.rotate(byAngle: .pi, duration: 3)))
            extra = star
            halo.color = UIColor(hex: "#7B5CFF")
            halo.size = CGSize(width: radius * 9, height: radius * 9)
        case .lava, .toxic:
            core.color = colors.first ?? .white
        default:
            break
        }
        head.addChild(halo)
        if let extra { head.addChild(extra) }
        head.addChild(core)
        head.zPosition = 10
        node.addChild(head)
    }

    /// Nouvelle manche : la traînée repart de zéro.
    func reset() {
        history = []
        lastPosition = nil
        head.alpha = 1
        head.setScale(1)
    }

    /// Appelé à chaque image avec la position affichée du point.
    func update(position: CGPoint, time: TimeInterval, dt: CGFloat, visible: Bool) {
        head.position = position
        particles.update(dt: dt)
        let moved = lastPosition.map { hypot(position.x - $0.x, position.y - $0.y) } ?? 0
        lastPosition = position
        if visible, history.last != position {
            history.append(style == .pixel ? snap(position) : position)
            if history.count > length { history.removeFirst() }
        }
        guard visible else {
            dots.forEach { $0.alpha = 0 }
            ribbonGlow?.path = nil
            ribbonCore?.path = nil
            return
        }
        animateHead(time: time)
        drawTrail(time: time)
        emit(moved: moved, dt: dt, position: position, time: time)
    }

    // MARK: Traînée

    private func drawTrail(time: TimeInterval) {
        if let glow = ribbonGlow, let inner = ribbonCore {
            guard history.count > 1 else {
                glow.path = nil
                inner.path = nil
                return
            }
            let path = CGMutablePath()
            path.move(to: history[0])
            for i in 1..<history.count {
                let mid = CGPoint(x: (history[i - 1].x + history[i].x) / 2, y: (history[i - 1].y + history[i].y) / 2)
                path.addQuadCurve(to: mid, control: history[i - 1])
            }
            path.addLine(to: history[history.count - 1])
            glow.path = path
            inner.path = path
            let colors = skin.colors.map { UIColor(hex: $0) }
            glow.strokeColor = UIColor.interpolate(colors, at: 0.5 + 0.5 * sin(time * 2))
            return
        }
        for (i, dot) in dots.enumerated() {
            let index = history.count - dots.count + i
            guard index >= 0 else {
                dot.alpha = 0
                continue
            }
            let k = CGFloat(i + 1) / CGFloat(dots.count)
            dot.position = history[index]
            dot.color = theme.trailColor(at: Double(1 - k), time: time)
            switch style {
            case .comet:
                dot.alpha = 0.85 * k * k
                dot.setScale(0.15 + 0.85 * k)
            case .pixel:
                dot.alpha = k > 0.15 ? 0.95 : 0
                dot.setScale(1)
            case .bubbles:
                dot.alpha = 0.8 * k
                dot.setScale(0.4 + 0.6 * k + 0.08 * CGFloat(sin(time * 8 + Double(i))))
            case .sakura:
                dot.alpha = 0.9 * k
                dot.setScale(0.5 + 0.5 * k)
                dot.zRotation += 0.04
            case .fire, .galaxy, .lava:
                dot.alpha = 0.8 * k
                dot.setScale(0.3 + 0.75 * k + 0.12 * CGFloat(sin(time * 20 + Double(i) * 1.3)))
            default:
                dot.alpha = 0.75 * k
                dot.setScale(0.35 + 0.65 * k)
            }
        }
    }

    private func snap(_ p: CGPoint) -> CGPoint {
        let grid = radius * 1.3
        return CGPoint(x: (p.x / grid).rounded() * grid, y: (p.y / grid).rounded() * grid)
    }

    private func animateHead(time: TimeInterval) {
        switch style {
        case .fire:
            halo.alpha = 0.55 + 0.25 * CGFloat(sin(time * 23)) * CGFloat(sin(time * 7))
            halo.setScale(1 + 0.12 * CGFloat(sin(time * 17)))
        case .electric:
            halo.alpha = CGFloat.random(in: 0.35...0.85)
        case .galaxy:
            extra?.alpha = 0.6 + 0.4 * CGFloat(sin(time * 5))
        case .rainbow:
            halo.color = theme.trailColor(at: 0, time: time)
        default:
            break
        }
    }

    // MARK: Particules

    private func emit(moved: CGFloat, dt: CGFloat, position: CGPoint, time: TimeInterval) {
        let colors = skin.colors.map { UIColor(hex: $0) }
        func random(_ colors: [UIColor]) -> UIColor { colors.randomElement() ?? .white }
        let r = radius
        /// Particules par unité parcourue, et par seconde à l'arrêt.
        let (perUnit, perSecond): (CGFloat, CGFloat) = switch style {
        case .fire: (0.10, 26)
        case .galaxy: (0.08, 10)
        case .bubbles: (0.035, 2)
        case .sakura: (0.04, 3)
        case .electric: (0.07, 8)
        case .lava: (0.045, 4)
        case .toxic: (0.045, 5)
        case .comet: (0.05, 0)
        default: (0, 0)
        }
        guard perUnit > 0 || perSecond > 0 else { return }
        emitCarry += moved * perUnit
        idleCarry += dt * perSecond
        var count = Int(emitCarry) + Int(idleCarry)
        emitCarry -= CGFloat(Int(emitCarry))
        idleCarry -= CGFloat(Int(idleCarry))
        count = min(count, 8)
        for _ in 0..<count {
            let jitter = CGPoint(x: position.x + .random(in: -r * 0.6...r * 0.6), y: position.y + .random(in: -r * 0.6...r * 0.6))
            var spec = ParticleField.Spec()
            spec.blend = blend
            switch style {
            case .fire:
                if Int.random(in: 0..<4) == 0 {
                    // Braise : petit point orange qui s'envole loin et scintille.
                    spec.texture = Textures.disc
                    spec.size = .random(in: r * 0.25...r * 0.45)
                    spec.velocity = CGVector(dx: .random(in: -r * 5...r * 5), dy: .random(in: r * 4...r * 11))
                    spec.life = .random(in: 0.8...1.4)
                    spec.color = UIColor(hex: "#FFC23D")
                    spec.endColor = UIColor(hex: "#E8230E")
                    spec.twinkle = true
                    spec.endScale = 0.4
                } else {
                    // Flamme : monte, rétrécit, passe du jaune au rouge.
                    spec.texture = Textures.flame
                    spec.size = .random(in: r * 1.8...r * 3)
                    spec.stretch = 1.35
                    spec.velocity = CGVector(dx: .random(in: -r * 1.2...r * 1.2), dy: .random(in: r * 5...r * 9))
                    spec.life = .random(in: 0.4...0.65)
                    spec.color = UIColor(hex: "#FFE27A")
                    spec.endColor = UIColor(hex: "#C41A0A")
                    spec.endScale = 0.15
                    spec.alpha = 0.9
                }
            case .galaxy:
                if Bool.random() {
                    spec.texture = Textures.star
                    spec.size = .random(in: r * 0.8...r * 1.9)
                    spec.velocity = CGVector(dx: .random(in: -r...r), dy: .random(in: -r...r))
                    spec.life = .random(in: 0.9...1.6)
                    spec.color = random(colors)
                    spec.twinkle = true
                    spec.spin = .random(in: -2...2)
                    spec.rotation = .random(in: 0...(.pi))
                    spec.endScale = 0.3
                } else {
                    spec.size = .random(in: r * 0.6...r * 1.2)
                    spec.velocity = CGVector(dx: .random(in: -r * 0.6...r * 0.6), dy: .random(in: -r * 0.6...r * 0.6))
                    spec.life = .random(in: 0.6...1.1)
                    spec.color = random([UIColor(hex: "#7B5CFF"), UIColor(hex: "#FF6BD6"), UIColor(hex: "#5AC8FF")])
                    spec.alpha = 0.6
                    spec.endScale = 1.6
                }
            case .bubbles:
                spec.texture = Textures.bubble
                spec.size = .random(in: r * 0.8...r * 2)
                spec.velocity = CGVector(dx: .random(in: -r...r), dy: .random(in: r * 2.5...r * 5))
                spec.life = .random(in: 0.9...1.7)
                spec.color = random(colors)
                spec.alpha = 0.85
                spec.pop = true
                spec.blend = theme.isLight ? .alpha : .add
            case .sakura:
                spec.texture = Textures.petal
                spec.size = .random(in: r * 0.9...r * 1.5)
                spec.velocity = CGVector(dx: .random(in: -r * 2...r * 2), dy: .random(in: -r * 3 ... -r))
                spec.gravity = -r * 2
                spec.life = .random(in: 1.2...1.9)
                spec.color = random(colors)
                spec.spin = .random(in: -4...4)
                spec.rotation = .random(in: 0...(2 * .pi))
                spec.endScale = 0.7
                spec.blend = .alpha
            case .electric:
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: r * 8...r * 15)
                spec.texture = Textures.disc
                spec.size = .random(in: r * 0.2...r * 0.35)
                spec.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                spec.life = .random(in: 0.12...0.28)
                spec.color = random(colors)
                spec.endScale = 0.3
            case .lava:
                spec.texture = Textures.drop
                spec.size = .random(in: r * 0.7...r * 1.2)
                spec.stretch = 1.2
                spec.velocity = CGVector(dx: .random(in: -r * 1.5...r * 1.5), dy: .random(in: 0...r * 3))
                spec.gravity = -r * 38
                spec.life = .random(in: 0.6...0.95)
                spec.color = UIColor(hex: "#FFB02E")
                spec.endColor = UIColor(hex: "#2A0703")
                spec.endScale = 0.6
                spec.blend = .alpha
            case .toxic:
                if Int.random(in: 0..<3) == 0 {
                    spec.size = .random(in: r * 0.7...r * 1.3)
                    spec.velocity = CGVector(dx: .random(in: -r...r), dy: .random(in: r...r * 3))
                    spec.life = .random(in: 0.5...0.9)
                    spec.color = UIColor(hex: "#C8FF4D")
                    spec.alpha = 0.7
                    spec.endScale = 1.5
                } else {
                    spec.texture = Textures.drop
                    spec.size = .random(in: r * 0.55...r * 0.9)
                    spec.stretch = 1.6
                    spec.velocity = CGVector(dx: 0, dy: -r)
                    spec.gravity = -r * 22
                    spec.life = .random(in: 0.7...1.1)
                    spec.color = UIColor(hex: "#A8FF3D")
                    spec.endColor = UIColor(hex: "#1E6B10")
                    spec.endScale = 0.8
                    spec.blend = .alpha
                }
            case .comet:
                spec.size = .random(in: r * 0.4...r * 0.8)
                spec.velocity = CGVector(dx: .random(in: -r * 0.5...r * 0.5), dy: .random(in: -r * 0.5...r * 0.5))
                spec.life = .random(in: 0.4...0.8)
                spec.color = random(colors)
                spec.twinkle = true
            default:
                continue
            }
            particles.emit(spec, at: jitter)
        }

        // Électrique : un éclair en zigzag entre le point et sa traînée, de temps en temps.
        if let bolt {
            boltTimer -= dt
            bolt.alpha = max(0, bolt.alpha - dt * 12)
            if boltTimer <= 0, history.count > 6 {
                boltTimer = .random(in: 0.07...0.2)
                let target = history[history.count - Int.random(in: 4...min(10, history.count - 1))]
                let path = CGMutablePath()
                path.move(to: position)
                for step in 1...5 {
                    let t = CGFloat(step) / 6
                    path.addLine(to: CGPoint(x: position.x + (target.x - position.x) * t + .random(in: -r...r),
                                             y: position.y + (target.y - position.y) * t + .random(in: -r...r)))
                }
                path.addLine(to: target)
                bolt.path = path
                bolt.alpha = 1
            }
        }
    }

    func clearParticles() {
        particles.clear()
    }
}
