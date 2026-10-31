import SpriteKit
import UIKit

/// Textures dessinées une fois au lancement (aucune image à produire à la main). Toutes blanches : la couleur vient du
/// sprite (`color` + `colorBlendFactor = 1`).
enum Textures {
    /// Halo : blanc au centre, transparent au bord.
    static let glow: SKTexture = make(size: 128) { context, rect in
        let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.35, 1])!
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: rect.width / 2, options: [])
    }

    /// Disque plein.
    static let disc: SKTexture = make(size: 128) { context, rect in
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
    }

    /// Bulle : anneau fin avec un reflet.
    static let bubble: SKTexture = make(size: 128) { context, rect in
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(9)
        context.strokeEllipse(in: rect.insetBy(dx: 8, dy: 8))
        context.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 12, dy: 12))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: rect.width * 0.28, y: rect.height * 0.24, width: rect.width * 0.18, height: rect.height * 0.14))
    }

    /// Carré plein (pixel).
    static let square: SKTexture = make(size: 64) { context, rect in
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect.insetBy(dx: 4, dy: 4))
    }

    /// Étoile à 4 branches, fine et brillante.
    static let star: SKTexture = make(size: 128) { context, rect in
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let long = rect.width / 2
        let thin = rect.width * 0.07
        let path = CGMutablePath()
        path.move(to: CGPoint(x: c.x, y: c.y - long))
        path.addQuadCurve(to: CGPoint(x: c.x + long, y: c.y), control: CGPoint(x: c.x + thin, y: c.y - thin))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + long), control: CGPoint(x: c.x + thin, y: c.y + thin))
        path.addQuadCurve(to: CGPoint(x: c.x - long, y: c.y), control: CGPoint(x: c.x - thin, y: c.y + thin))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - long), control: CGPoint(x: c.x - thin, y: c.y - thin))
        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
        let colors = [UIColor.white.withAlphaComponent(0.8).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: rect.width * 0.22, options: [])
    }

    /// Pétale de cerisier.
    static let petal: SKTexture = make(size: 96) { context, rect in
        let w = rect.width
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w * 0.5, y: w * 0.95))
        path.addCurve(to: CGPoint(x: w * 0.42, y: w * 0.08), control1: CGPoint(x: w * 0.05, y: w * 0.7), control2: CGPoint(x: w * 0.1, y: w * 0.2))
        path.addLine(to: CGPoint(x: w * 0.5, y: w * 0.2))
        path.addLine(to: CGPoint(x: w * 0.58, y: w * 0.08))
        path.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.95), control1: CGPoint(x: w * 0.9, y: w * 0.2), control2: CGPoint(x: w * 0.95, y: w * 0.7))
        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    }

    /// Goutte (pointe en haut).
    static let drop: SKTexture = make(size: 96) { context, rect in
        let w = rect.width
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w * 0.5, y: w * 0.04))
        path.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.96), control1: CGPoint(x: w * 0.62, y: w * 0.35), control2: CGPoint(x: w * 0.98, y: w * 0.96))
        path.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.04), control1: CGPoint(x: w * 0.02, y: w * 0.96), control2: CGPoint(x: w * 0.38, y: w * 0.35))
        context.addPath(path)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    }

    /// Flamme (pointe en haut), au bord doux.
    static let flame: SKTexture = make(size: 128) { context, rect in
        let w = rect.width
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w * 0.5, y: w * 0.02))
        path.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.98), control1: CGPoint(x: w * 0.75, y: w * 0.35), control2: CGPoint(x: w * 1.0, y: w * 0.98))
        path.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.02), control1: CGPoint(x: w * 0.0, y: w * 0.98), control2: CGPoint(x: w * 0.25, y: w * 0.35))
        context.addPath(path)
        context.clip()
        let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.25).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        let c = CGPoint(x: w * 0.5, y: w * 0.72)
        context.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: w * 0.6, options: [.drawsAfterEndLocation])
    }

    static func make(size: CGFloat, draw: (CGContext, CGRect) -> Void) -> SKTexture {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { draw($0.cgContext, rect) }
        return SKTexture(image: image)
    }
}

/// Petit système de particules fait maison (léger, sans fichier) : chaque particule a une vitesse, une durée de vie,
/// une gravité, une rotation, et change de taille, d'opacité et de couleur au fil de sa vie.
final class ParticleField: SKNode {
    struct Spec {
        var texture: SKTexture = Textures.glow
        var size: CGFloat = 30
        var velocity: CGVector = .zero
        var life: CGFloat = 0.6
        var color: UIColor = .white
        /// Couleur en fin de vie (nil : garde la couleur de départ).
        var endColor: UIColor?
        /// Accélération verticale (unités par seconde²) ; négative : tombe.
        var gravity: CGFloat = 0
        var spin: CGFloat = 0
        var endScale: CGFloat = 0.2
        var alpha: CGFloat = 1
        var blend: SKBlendMode = .add
        /// Scintille au lieu de s'éteindre doucement.
        var twinkle = false
        /// Grossit et s'éteint d'un coup en fin de vie (bulle qui éclate).
        var pop = false
        var rotation: CGFloat = 0
        /// Étirement vertical (goutte, flamme).
        var stretch: CGFloat = 1
    }

    private struct Particle {
        let node: SKSpriteNode
        let spec: Spec
        var velocity: CGVector
        var age: CGFloat = 0
    }

    private var particles: [Particle] = []
    private var pool: [SKSpriteNode] = []
    private let limit: Int

    init(limit: Int = 220) {
        self.limit = limit
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    func emit(_ spec: Spec, at position: CGPoint) {
        guard particles.count < limit else { return }
        let node = pool.popLast() ?? SKSpriteNode()
        node.texture = spec.texture
        node.size = CGSize(width: spec.size, height: spec.size * spec.stretch)
        node.color = spec.color
        node.colorBlendFactor = 1
        node.blendMode = spec.blend
        node.alpha = spec.alpha
        node.position = position
        node.zRotation = spec.rotation
        node.setScale(1)
        addChild(node)
        particles.append(Particle(node: node, spec: spec, velocity: spec.velocity))
    }

    func update(dt: CGFloat) {
        guard !particles.isEmpty else { return }
        var kept: [Particle] = []
        kept.reserveCapacity(particles.count)
        for var p in particles {
            p.age += dt
            let t = p.age / p.spec.life
            if t >= 1 {
                p.node.removeFromParent()
                pool.append(p.node)
                continue
            }
            p.velocity.dy += p.spec.gravity * dt
            p.node.position.x += p.velocity.dx * dt
            p.node.position.y += p.velocity.dy * dt
            p.node.zRotation += p.spec.spin * dt
            if p.spec.pop {
                p.node.setScale(t > 0.85 ? 1 + (t - 0.85) * 4 : 1)
                p.node.alpha = p.spec.alpha * (t > 0.85 ? (1 - t) / 0.15 : 1)
            } else if p.spec.twinkle {
                p.node.setScale(1 + (p.spec.endScale - 1) * t)
                p.node.alpha = p.spec.alpha * (1 - t) * (0.55 + 0.45 * CGFloat(sin(Double(p.age) * 26 + Double(p.spec.rotation) * 7)))
            } else {
                p.node.setScale(1 + (p.spec.endScale - 1) * t)
                p.node.alpha = p.spec.alpha * (1 - t * t)
            }
            if let end = p.spec.endColor {
                p.node.color = UIColor.interpolate([p.spec.color, end], at: Double(t))
            }
            kept.append(p)
        }
        particles = kept
    }

    func clear() {
        for p in particles {
            p.node.removeFromParent()
            pool.append(p.node)
        }
        particles = []
    }
}
