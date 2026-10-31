import SpriteKit
import UIKit
import EchoCore

/// Décor animé derrière l'arène (étoiles, océan, forêt, encre, synthwave), dessiné par le code.
/// Il reste discret (faible opacité) pour que les fantômes et les orbes restent bien lisibles.
/// Les tailles sont en points d'écran, proportionnelles à la largeur de la zone (`unit`).
final class DecorLayer: SKNode {
    private let decor: Skin
    private let size: CGSize
    private let unit: CGFloat
    private let particles = ParticleField(limit: 80)
    private var timer: CGFloat = 0
    private var gridLines: SKShapeNode?
    private var horizon: CGFloat = 0

    init(decor: Skin, size: CGSize) {
        self.decor = decor
        self.size = size
        unit = max(size.width, 1) / 390
        super.init()
        addChild(particles)
        particles.zPosition = 5
        switch decor.style {
        case .ocean: buildOcean()
        case .forest: buildForest()
        case .ink: buildInk()
        case .synthwave: buildSynthwave()
        default: buildNight()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    func update(time: TimeInterval, dt: CGFloat) {
        particles.update(dt: dt)
        timer -= dt
        switch decor.style {
        case .ocean:
            if timer <= 0 {
                timer = .random(in: 0.15...0.4)
                var spec = ParticleField.Spec()
                spec.texture = Textures.bubble
                spec.size = CGFloat.random(in: 4...13) * unit
                spec.velocity = CGVector(dx: CGFloat.random(in: -6...6) * unit, dy: CGFloat.random(in: 35...80) * unit)
                spec.life = .random(in: 6...11)
                spec.color = UIColor(hex: "#BFF6FF")
                spec.alpha = 0.35
                spec.endScale = 1.2
                particles.emit(spec, at: CGPoint(x: .random(in: 0...size.width), y: -10))
            }
        case .night, .synthwave:
            if timer <= 0 {
                timer = .random(in: 3.5...7)
                shootingStar()
            }
            if let gridLines { gridLines.path = gridPath(phase: CGFloat((time * 0.45).truncatingRemainder(dividingBy: 1))) }
        default:
            break
        }
    }

    // MARK: Nuit

    private func buildNight() {
        nebula(UIColor(hex: "#5A3DFF"), at: CGPoint(x: size.width * 0.2, y: size.height * 0.75), radius: 260)
        nebula(UIColor(hex: "#FF4D9A"), at: CGPoint(x: size.width * 0.85, y: size.height * 0.3), radius: 220)
        stars(count: 110, maxY: size.height)
        // Lune discrète en haut à droite.
        let moon = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 46 * unit, height: 46 * unit))
        moon.color = UIColor(hex: "#FFF4D6")
        moon.colorBlendFactor = 1
        moon.alpha = 0.55
        moon.position = CGPoint(x: size.width * 0.82, y: size.height * 0.9)
        let glow = SKSpriteNode(texture: Textures.glow, size: CGSize(width: 150 * unit, height: 150 * unit))
        glow.color = UIColor(hex: "#FFF4D6")
        glow.colorBlendFactor = 1
        glow.alpha = 0.25
        glow.blendMode = .add
        glow.position = moon.position
        addChild(glow)
        addChild(moon)
    }

    private func stars(count: Int, maxY: CGFloat, minY: CGFloat = 0) {
        for i in 0..<count {
            let big = i % 9 == 0
            let star = SKSpriteNode(texture: big ? Textures.star : Textures.disc)
            let s = (big ? CGFloat.random(in: 9...15) : CGFloat.random(in: 1.5...3.8)) * unit
            star.size = CGSize(width: s, height: s)
            star.color = [UIColor.white, UIColor(hex: "#CFE3FF"), UIColor(hex: "#FFE9C9")].randomElement()!
            star.colorBlendFactor = 1
            star.blendMode = .add
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: minY...maxY))
            let base = CGFloat.random(in: 0.3...0.9)
            star.alpha = base
            let duration = Double.random(in: 0.8...3)
            star.run(.repeatForever(.sequence([.fadeAlpha(to: base * 0.25, duration: duration),
                                               .fadeAlpha(to: base, duration: duration)])))
            addChild(star)
        }
    }

    private func nebula(_ color: UIColor, at point: CGPoint, radius: CGFloat) {
        let cloud = SKSpriteNode(texture: Textures.glow, size: CGSize(width: radius * 2 * unit, height: radius * 1.5 * unit))
        cloud.color = color
        cloud.colorBlendFactor = 1
        cloud.alpha = 0.16
        cloud.blendMode = .add
        cloud.position = point
        cloud.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 6), .scale(to: 1, duration: 6)])))
        addChild(cloud)
    }

    private func shootingStar() {
        let start = CGPoint(x: .random(in: size.width * 0.3...size.width * 1.1), y: .random(in: size.height * 0.6...size.height))
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 70 * unit, y: 35 * unit))
        let streak = SKShapeNode(path: path)
        streak.strokeColor = .white
        streak.lineWidth = 2 * unit
        streak.glowWidth = 2 * unit
        streak.alpha = 0
        streak.position = start
        streak.zPosition = 2
        addChild(streak)
        let move = SKAction.moveBy(x: -260 * unit, y: -130 * unit, duration: 0.8)
        streak.run(.sequence([.group([move, .sequence([.fadeAlpha(to: 0.8, duration: 0.15), .fadeOut(withDuration: 0.65)])]),
                              .removeFromParent()]))
    }

    // MARK: Océan

    private func buildOcean() {
        // Rayons de lumière qui descendent de la surface et ondulent.
        for i in 0..<6 {
            let ray = SKSpriteNode(texture: Textures.glow)
            ray.size = CGSize(width: CGFloat.random(in: 50...110) * unit, height: size.height * 1.1)
            ray.anchorPoint = CGPoint(x: 0.5, y: 1)
            ray.position = CGPoint(x: size.width * (0.05 + 0.18 * CGFloat(i)) + CGFloat.random(in: -20...20), y: size.height + 20)
            ray.color = UIColor(hex: "#9FF3FF")
            ray.colorBlendFactor = 1
            ray.blendMode = .add
            ray.alpha = .random(in: 0.07...0.13)
            ray.zRotation = .random(in: -0.35 ... -0.15)
            let sway = Double.random(in: 4...7)
            ray.run(.repeatForever(.sequence([.rotate(byAngle: 0.08, duration: sway), .rotate(byAngle: -0.08, duration: sway)])))
            addChild(ray)
        }
        // Reflets de la surface.
        let surface = SKSpriteNode(texture: Textures.glow, size: CGSize(width: size.width * 1.5, height: 160 * unit))
        surface.position = CGPoint(x: size.width / 2, y: size.height)
        surface.color = UIColor(hex: "#7FE9FF")
        surface.colorBlendFactor = 1
        surface.blendMode = .add
        surface.alpha = 0.18
        surface.run(.repeatForever(.sequence([.fadeAlpha(to: 0.1, duration: 2.5), .fadeAlpha(to: 0.2, duration: 2.5)])))
        addChild(surface)
        // Petits poissons lumineux au loin.
        for _ in 0..<6 { addFish() }
        // Plancton.
        for _ in 0..<30 {
            let speck = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 2.5 * unit, height: 2.5 * unit))
            speck.color = UIColor(hex: "#BFF6FF")
            speck.colorBlendFactor = 1
            speck.alpha = .random(in: 0.15...0.4)
            speck.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            wander(speck, distance: 20 * unit, duration: 4)
            addChild(speck)
        }
    }

    private func addFish() {
        let fish = SKNode()
        let body = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 18 * unit, height: 8 * unit))
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -8 * unit, y: 0))
        tailPath.addLine(to: CGPoint(x: -15 * unit, y: 5 * unit))
        tailPath.addLine(to: CGPoint(x: -15 * unit, y: -5 * unit))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        let color = [UIColor(hex: "#7CFFE4"), UIColor(hex: "#FFB38F"), UIColor(hex: "#B8C8FF")].randomElement()!
        tail.fillColor = color
        tail.strokeColor = .clear
        body.color = color
        body.colorBlendFactor = 1
        fish.addChild(tail)
        fish.addChild(body)
        fish.alpha = .random(in: 0.18...0.35)
        let scale = CGFloat.random(in: 0.6...1.2)
        fish.setScale(scale)
        let leftToRight = Bool.random()
        if !leftToRight { fish.xScale = -scale }
        let y = CGFloat.random(in: size.height * 0.1...size.height * 0.8)
        let startX = leftToRight ? -40 : size.width + 40
        let endX = leftToRight ? size.width + 40 : -40
        fish.position = CGPoint(x: .random(in: 0...size.width), y: y)
        addChild(fish)
        let swim = SKAction.repeatForever(.sequence([
            .moveTo(x: endX, duration: Double.random(in: 18...32)),
            .moveTo(x: startX, duration: 0),
        ]))
        fish.run(swim)
        fish.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8 * unit, duration: 1.6), .moveBy(x: 0, y: -8 * unit, duration: 1.6)])))
    }

    // MARK: Forêt

    private func buildForest() {
        // Brume qui dérive.
        for i in 0..<3 {
            let mist = SKSpriteNode(texture: Textures.glow, size: CGSize(width: size.width * 1.6, height: 280 * unit))
            mist.position = CGPoint(x: size.width / 2, y: size.height * (0.2 + 0.3 * CGFloat(i)))
            mist.color = UIColor(hex: "#CFFFE0")
            mist.colorBlendFactor = 1
            mist.blendMode = .add
            mist.alpha = 0.06
            let drift = Double.random(in: 9...14)
            mist.run(.repeatForever(.sequence([.moveBy(x: 60 * unit, y: 0, duration: drift), .moveBy(x: -60 * unit, y: 0, duration: drift)])))
            addChild(mist)
        }
        // Feuillages en silhouette sur les bords.
        leafCluster(at: CGPoint(x: 0, y: size.height), count: 11, angle: -0.6)
        leafCluster(at: CGPoint(x: size.width, y: size.height), count: 11, angle: -2.5)
        leafCluster(at: CGPoint(x: 0, y: 0), count: 8, angle: 0.7)
        leafCluster(at: CGPoint(x: size.width, y: 0), count: 8, angle: 2.4)
        // Lucioles.
        for _ in 0..<26 {
            let fly = SKSpriteNode(texture: Textures.glow, size: CGSize(width: 16 * unit, height: 16 * unit))
            fly.color = UIColor(hex: "#E8FF7A")
            fly.colorBlendFactor = 1
            fly.blendMode = .add
            fly.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            let on = Double.random(in: 0.6...1.6)
            fly.alpha = 0
            fly.run(.sequence([.wait(forDuration: .random(in: 0...2)),
                               .repeatForever(.sequence([.fadeAlpha(to: 0.9, duration: on), .fadeAlpha(to: 0.05, duration: on)]))]))
            wander(fly, distance: 45 * unit, duration: 3)
            addChild(fly)
        }
    }

    private func leafCluster(at origin: CGPoint, count: Int, angle: CGFloat) {
        for i in 0..<count {
            let length = CGFloat.random(in: 70...140) * unit
            let leaf = CGMutablePath()
            leaf.move(to: .zero)
            leaf.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: length * 0.28))
            leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: -length * 0.28))
            let shape = SKShapeNode(path: leaf)
            shape.fillColor = [UIColor(hex: "#06180E"), UIColor(hex: "#0A2416"), UIColor(hex: "#0F311D")].randomElement()!
            shape.strokeColor = UIColor(hex: "#1F4D33").withAlphaComponent(0.6)
            shape.lineWidth = 1
            shape.position = CGPoint(x: origin.x + CGFloat.random(in: -20...20) * unit, y: origin.y + CGFloat.random(in: -20...20) * unit)
            shape.zRotation = angle + CGFloat(i - count / 2) * 0.22 + CGFloat.random(in: -0.1...0.1)
            shape.alpha = 0.92
            shape.zPosition = 6
            let sway = Double.random(in: 2.5...4)
            shape.run(.repeatForever(.sequence([.rotate(byAngle: 0.05, duration: sway), .rotate(byAngle: -0.05, duration: sway)])))
            addChild(shape)
        }
    }

    // MARK: Encre

    private func buildInk() {
        // Toujours les mêmes éclaboussures (graine fixe) : un décor dessiné, pas du bruit.
        var random = SeededRandom(seed: 7)
        let ink = UIColor(hex: "#1C1A17")
        let spots: [CGPoint] = [
            CGPoint(x: 0.08, y: 0.9), CGPoint(x: 0.92, y: 0.78), CGPoint(x: 0.12, y: 0.35),
            CGPoint(x: 0.88, y: 0.15), CGPoint(x: 0.5, y: 0.97), CGPoint(x: 0.55, y: 0.04), CGPoint(x: 0.95, y: 0.48),
        ]
        for spot in spots {
            let center = CGPoint(x: spot.x * size.width, y: spot.y * size.height)
            let radius = CGFloat(random.between(28, 62)) * unit
            let alpha = CGFloat(random.between(0.06, 0.11))
            blob(at: center, radius: radius, color: ink, alpha: alpha)
            for _ in 0..<Int(random.between(6, 11)) {
                let angle = random.between(0, 2 * .pi)
                let distance = CGFloat(random.between(1.1, 2.3)) * radius
                let r = CGFloat(random.between(2.5, 11)) * unit
                blob(at: CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance), radius: r, color: ink, alpha: alpha)
            }
        }
        // Coup de pinceau.
        let stroke = CGMutablePath()
        stroke.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.62))
        stroke.addCurve(to: CGPoint(x: size.width * 0.4, y: size.height * 0.58),
                        control1: CGPoint(x: size.width * 0.15, y: size.height * 0.68), control2: CGPoint(x: size.width * 0.3, y: size.height * 0.52))
        let brush = SKShapeNode(path: stroke)
        brush.strokeColor = ink.withAlphaComponent(0.07)
        brush.lineWidth = 14 * unit
        brush.lineCap = .round
        addChild(brush)
        // Grain du papier.
        for _ in 0..<220 {
            let grain = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 1.6 * unit, height: 1.6 * unit))
            grain.color = UIColor(hex: "#8A7350")
            grain.colorBlendFactor = 1
            grain.alpha = CGFloat(random.between(0.05, 0.15))
            grain.position = CGPoint(x: random.between(0, Double(size.width)), y: random.between(0, Double(size.height)))
            addChild(grain)
        }
    }

    private func blob(at point: CGPoint, radius: CGFloat, color: UIColor, alpha: CGFloat) {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = color.withAlphaComponent(alpha)
        node.strokeColor = .clear
        node.position = point
        addChild(node)
    }

    // MARK: Synthwave

    private func buildSynthwave() {
        horizon = size.height * 0.34
        stars(count: 45, maxY: size.height, minY: size.height * 0.55)
        // Soleil rayé avec halo.
        let diameter = size.width * 0.62
        let sunCenter = CGPoint(x: size.width / 2, y: horizon + diameter * 0.28)
        let halo = SKSpriteNode(texture: Textures.glow, size: CGSize(width: diameter * 2, height: diameter * 2))
        halo.color = UIColor(hex: "#FF2E97")
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.4
        halo.position = sunCenter
        addChild(halo)
        let sun = SKSpriteNode(texture: Self.sunTexture, size: CGSize(width: diameter, height: diameter))
        sun.position = sunCenter
        sun.alpha = 0.85
        sun.run(.repeatForever(.sequence([.fadeAlpha(to: 0.7, duration: 3), .fadeAlpha(to: 0.85, duration: 3)])))
        addChild(sun)
        // Montagnes.
        for (layer, color) in [(0, UIColor(hex: "#3A0E5C")), (1, UIColor(hex: "#1E0638"))] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: horizon))
            var x: CGFloat = 0
            var random = SeededRandom(seed: UInt64(11 + layer))
            while x < size.width {
                let peakX = x + CGFloat(random.between(30, 70)) * unit
                let peakY = horizon + CGFloat(random.between(layer == 0 ? 40 : 15, layer == 0 ? 110 : 55)) * unit
                path.addLine(to: CGPoint(x: peakX, y: peakY))
                x = peakX + CGFloat(random.between(30, 70)) * unit
                path.addLine(to: CGPoint(x: min(x, size.width), y: horizon + CGFloat(random.between(0, 18)) * unit))
            }
            path.addLine(to: CGPoint(x: size.width, y: horizon))
            path.closeSubpath()
            let mountains = SKShapeNode(path: path)
            mountains.fillColor = color
            mountains.strokeColor = UIColor(hex: "#FF2E97").withAlphaComponent(layer == 0 ? 0.7 : 0.4)
            mountains.lineWidth = 1.5 * unit
            mountains.glowWidth = layer == 0 ? 2 * unit : 0
            mountains.zPosition = 1 + CGFloat(layer)
            addChild(mountains)
        }
        // Sol et grille néon en perspective qui défile.
        let ground = SKSpriteNode(color: UIColor(hex: "#12002A"), size: CGSize(width: size.width, height: horizon))
        ground.anchorPoint = .zero
        ground.zPosition = 3
        addChild(ground)
        let vertical = CGMutablePath()
        let vanishing = CGPoint(x: size.width / 2, y: horizon)
        for i in -9...9 {
            vertical.move(to: vanishing)
            vertical.addLine(to: CGPoint(x: size.width / 2 + CGFloat(i) * size.width * 0.22, y: 0))
        }
        let verticalLines = SKShapeNode(path: vertical)
        verticalLines.strokeColor = UIColor(hex: "#FF2E97").withAlphaComponent(0.55)
        verticalLines.lineWidth = 1.5 * unit
        verticalLines.glowWidth = 1.5 * unit
        verticalLines.zPosition = 4
        addChild(verticalLines)
        let horizontal = SKShapeNode()
        horizontal.strokeColor = UIColor(hex: "#FF2E97").withAlphaComponent(0.55)
        horizontal.lineWidth = 1.5 * unit
        horizontal.glowWidth = 1.5 * unit
        horizontal.zPosition = 4
        addChild(horizontal)
        gridLines = horizontal
        let line = SKShapeNode(rect: CGRect(x: 0, y: horizon - 1, width: size.width, height: 2 * unit))
        line.fillColor = UIColor(hex: "#FFB1DA")
        line.strokeColor = .clear
        line.glowWidth = 3 * unit
        line.zPosition = 4
        addChild(line)
    }

    /// Lignes horizontales de la grille, de plus en plus serrées vers l'horizon ; `phase` les fait défiler.
    private func gridPath(phase: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let count = 12
        for k in 0..<count {
            let f = (CGFloat(k) + phase) / CGFloat(count)
            let y = horizon * (1 - f * f)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        return path
    }

    private static let sunTexture: SKTexture = Textures.make(size: 256) { context, rect in
        context.addEllipse(in: rect)
        context.clip()
        let colors = [UIColor(hex: "#FFE45C").cgColor, UIColor(hex: "#FF8A3D").cgColor, UIColor(hex: "#FF2E97").cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height), options: [])
        // Bandes transparentes dans la moitié basse, de plus en plus épaisses.
        context.setBlendMode(.clear)
        var y = rect.height * 0.52
        var thickness: CGFloat = 3
        while y < rect.height {
            context.fill(CGRect(x: 0, y: y, width: rect.width, height: thickness))
            y += thickness + 12
            thickness += 3
        }
    }

    // MARK: Outils

    /// Petite promenade au hasard, sans fin.
    private func wander(_ node: SKNode, distance: CGFloat, duration: Double) {
        let move = SKAction.moveBy(x: .random(in: -distance...distance), y: .random(in: -distance...distance),
                                   duration: .random(in: duration * 0.6...duration * 1.4))
        move.timingMode = .easeInEaseOut
        node.run(move) { [weak self, weak node] in
            guard let self, let node else { return }
            self.wander(node, distance: distance, duration: duration)
        }
    }
}
