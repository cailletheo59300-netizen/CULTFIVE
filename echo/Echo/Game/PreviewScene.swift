import SpriteKit
import UIKit
import EchoCore

/// Aperçu animé d'une apparence dans la boutique : le vrai décor et la vraie traînée (mêmes effets qu'en partie),
/// avec un point qui se promène, un fantôme et un orbe.
final class PreviewScene: SKScene {
    private let theme: GameTheme
    private let content = SKNode()
    private var decor: DecorLayer?
    private let trail: TrailRenderer
    private let ghost = SKNode()
    private let orb = SKNode()
    private var lastTime: TimeInterval?
    /// Zone logique de l'aperçu (unités d'arène), mise à l'échelle de la carte.
    private static let box = CGSize(width: 480, height: 300)

    init(theme: GameTheme) {
        self.theme = theme
        trail = TrailRenderer(skin: theme.trail, theme: theme, radius: 28)
        super.init(size: CGSize(width: 170, height: 110))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
        addChild(content)
        content.zPosition = 1

        let ghostCore = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 40, height: 40))
        ghostCore.color = theme.ghostColor
        ghostCore.colorBlendFactor = 1
        let ghostHalo = SKSpriteNode(texture: Textures.glow, size: CGSize(width: 110, height: 110))
        ghostHalo.color = theme.ghostColor
        ghostHalo.colorBlendFactor = 1
        ghostHalo.alpha = theme.isLight ? 0.25 : 0.55
        ghostHalo.blendMode = theme.glowBlend
        ghost.addChild(ghostHalo)
        ghost.addChild(ghostCore)
        content.addChild(ghost)

        let orbCore = SKSpriteNode(texture: Textures.disc, size: CGSize(width: 46, height: 46))
        orbCore.color = theme.orbColor
        orbCore.colorBlendFactor = 1
        let orbHalo = SKSpriteNode(texture: Textures.glow, size: CGSize(width: 130, height: 130))
        orbHalo.color = theme.orbColor
        orbHalo.colorBlendFactor = 1
        orbHalo.alpha = theme.isLight ? 0.3 : 0.5
        orbHalo.blendMode = theme.glowBlend
        orb.addChild(orbHalo)
        orb.addChild(orbCore)
        orb.position = CGPoint(x: Self.box.width * 0.2, y: Self.box.height * 0.28)
        orb.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 0.94, duration: 0.45)])))
        content.addChild(orb)

        content.addChild(trail.node)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1 else { return }
        let scale = min(size.width / Self.box.width, size.height / Self.box.height)
        content.setScale(scale)
        content.position = CGPoint(x: (size.width - Self.box.width * scale) / 2, y: (size.height - Self.box.height * scale) / 2)
        decor?.removeFromParent()
        let layer = DecorLayer(decor: theme.decor, size: size)
        layer.zPosition = 0
        addChild(layer)
        decor = layer
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(currentTime - (lastTime ?? currentTime), 0.1))
        lastTime = currentTime
        let t = currentTime
        let w = Self.box.width
        let h = Self.box.height
        let position = CGPoint(x: w * (0.5 + 0.36 * sin(t * 1.25)), y: h * (0.5 + 0.3 * sin(t * 2.1)))
        trail.update(position: position, time: t, dt: dt, visible: true)
        ghost.position = CGPoint(x: w * (0.5 + 0.34 * sin(t * 0.9 + 2)), y: h * (0.5 + 0.28 * cos(t * 1.4)))
        decor?.update(time: t, dt: dt)
    }
}
