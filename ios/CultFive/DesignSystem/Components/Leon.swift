import SwiftUI

/// Léon, le caméléon de Brainlix, version Pop : tout rond, grands yeux, joues roses.
/// Il prend la couleur du domaine, attrape les bonnes réponses avec sa langue, grisaille quand on se trompe,
/// passe à l'arc-en-ciel sur un sans-faute. Sa queue s'enroule avec la série.
/// Dessiné en code (aucun asset). Jamais pendant qu'on répond : seulement après, et aux moments forts.
struct Leon: View {
    enum Pose { case rest, curious, proud, sad, tongue, wave }

    var color: Color = .brand
    var pose: Pose = .rest
    /// Enroulement de la queue, de 0 (à peine) à 1 (spirale complète). Suit la série de jours.
    var curl: Double = 0.4
    /// Couleurs qui défilent (sans-faute).
    var rainbow = false
    /// Respiration, clignements, langue. Désactivé pour les rendus d'image.
    var animated = true
    /// Tenue imposée (essayage) ; sinon celle du joueur, transmise par l'environnement.
    var outfit: LeonOutfit? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.leonOutfit) private var playerOutfit
    @State private var start = Date()

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    canvas(time: timeline.date.timeIntervalSince(start))
                }
            } else {
                canvas(time: nil)
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .onAppear { start = Date() }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func canvas(time: Double?) -> some View {
        Canvas { context, size in
            LeonDrawing(color: color, pose: pose, curl: curl, rainbow: rainbow, time: time, outfit: outfit ?? playerOutfit)
                .draw(in: &context, size: size)
        }
    }

    private var accessibilityText: String {
        switch pose {
        case .proud: return "Léon, le caméléon, tout fier"
        case .sad: return "Léon, le caméléon, un peu dépité"
        case .tongue: return "Léon attrape la bonne réponse"
        case .wave: return "Léon te fait coucou"
        case .rest, .curious: return "Léon, le caméléon"
        }
    }
}

/// Le dessin, dans un repère 128 × 96.
private struct LeonDrawing {
    let color: Color
    let pose: Leon.Pose
    let curl: Double
    let rainbow: Bool
    let time: Double?
    let outfit: LeonOutfit

    private static let grey = Color(hex: 0xB9B6C9)
    private let dark = Color(hex: 0x1A1830)

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 128, size.height / 96)
        context.translateBy(x: (size.width - 128 * scale) / 2, y: (size.height - 96 * scale) / 2)
        context.scaleBy(x: scale, y: scale)

        let t = time ?? 0
        let animating = time != nil
        let skin = skinColor(t)

        // Ombre au sol (ne respire pas).
        context.fill(Path(ellipseIn: CGRect(x: 26, y: 84, width: 70, height: 7)), with: .color(.black.opacity(0.07)))

        // Respiration + petit saut de joie.
        var lift = animating ? sin(t * 2.4) * 1.1 : 0
        if pose == .proud, animating { lift -= abs(sin(t * 5)) * 3 }
        context.translateBy(x: 0, y: lift)
        if pose == .wave, animating {
            context.translateBy(x: 62, y: 80)
            context.rotate(by: .degrees(sin(t * 5) * 3))
            context.translateBy(x: -62, y: -80)
        }
        if pose == .curious {
            context.translateBy(x: 62, y: 56)
            context.rotate(by: .degrees(-5))
            context.translateBy(x: -62, y: -56)
        }

        // Coucou : la queue s'enroule et se déroule.
        let tailCurl = pose == .wave && animating ? curl + 0.18 * sin(t * 5) : curl
        if outfit.back != nil { LeonWear.back(outfit.back, in: &context, t: t) }
        drawTail(&context, skin: skin, curl: tailCurl)
        for x in [42.0, 70.0] {
            let foot = Path(roundedRect: CGRect(x: x, y: 72, width: 12, height: 12), cornerRadius: 6)
            fillShaded(&context, foot, skin, shade: 0.18)
        }

        // Crête (casque), puis corps et tête d'un seul tenant.
        fillShaded(&context, Path(ellipseIn: CGRect(x: 64, y: 14, width: 24, height: 20)), skin, shade: 0.12)
        var body = Path(ellipseIn: CGRect(x: 24, y: 38, width: 68, height: 44))
        body.addEllipse(in: CGRect(x: 62, y: 22, width: 48, height: 48))
        context.fill(body, with: .color(skin))

        // Ventre clair, taches sur le dos.
        context.fill(Path(ellipseIn: CGRect(x: 34, y: 64, width: 48, height: 13)), with: .color(.white.opacity(0.24)))
        for (x, y, r) in [(44.0, 46.0, 3.4), (55.0, 42.0, 2.8), (35.0, 54.0, 2.6)] {
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(.white.opacity(0.28)))
        }

        drawEye(&context, skin: skin, t: t, animating: animating)

        // Joue.
        context.fill(Path(ellipseIn: CGRect(x: 79, y: 54, width: 11, height: 7)), with: .color(Color.blush.opacity(pose == .sad ? 0.35 : 0.85)))
        drawMouth(&context, t: t, animating: animating)
        LeonWear.neck(outfit.neck, in: &context)
        LeonWear.eyes(outfit.eyes, in: &context)
        LeonWear.hat(outfit.hat, in: &context)
        if outfit.skin == "skin_gold" { drawSparkles(&context, t: t + 1.3, animating: animating) }
        if pose == .proud { drawSparkles(&context, t: t, animating: animating) }
    }

    private func skinColor(_ t: Double) -> Color {
        if pose == .sad { return Self.grey }
        if rainbow { return Color(hue: (t * 0.22).truncatingRemainder(dividingBy: 1), saturation: 0.62, brightness: 0.96) }
        if let skin = LeonWear.skinColor(outfit.skin) { return skin }
        return color
    }

    private func fillShaded(_ context: inout GraphicsContext, _ path: Path, _ skin: Color, shade: Double) {
        context.fill(path, with: .color(skin))
        context.fill(path, with: .color(.black.opacity(shade)))
    }

    /// Queue en spirale, effilée, qui s'enroule vers le bas.
    private func drawTail(_ context: inout GraphicsContext, skin: Color, curl: Double) {
        let center = CGPoint(x: 18, y: 62)
        let radius0 = 14.0
        let startAngle = -0.6
        let sweep = (0.7 + min(max(curl, 0), 1) * 1.1) * 2 * .pi
        let steps = 48
        var previous: CGPoint?
        for i in 0...steps {
            let s = Double(i) / Double(steps)
            let angle = startAngle - s * sweep
            let radius = radius0 * (1 - s * 0.72)
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if let previous {
                var segment = Path()
                segment.move(to: previous)
                segment.addLine(to: point)
                let width = 11 - s * 6
                context.stroke(segment, with: .color(skin), style: StrokeStyle(lineWidth: width, lineCap: .round))
                context.stroke(segment, with: .color(.black.opacity(0.1)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            previous = point
        }
    }

    private func drawEye(_ context: inout GraphicsContext, skin: Color, t: Double, animating: Bool) {
        let center = CGPoint(x: 90, y: 40)
        let eyeRect = CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)
        // Tourelle de l'œil (un peu plus sombre), puis le blanc.
        fillShaded(&context, Path(ellipseIn: eyeRect.insetBy(dx: -3, dy: -3)), skin, shade: 0.08)
        context.fill(Path(ellipseIn: eyeRect), with: .color(.white))

        let blinking = animating && pose != .proud && t.truncatingRemainder(dividingBy: 4.2) > 4.05
        if pose == .proud || blinking {
            // Œil fermé, content : un arc « ^ ».
            var arc = Path()
            arc.move(to: CGPoint(x: center.x - 7, y: center.y + 2))
            arc.addQuadCurve(to: CGPoint(x: center.x + 7, y: center.y + 2),
                             control: CGPoint(x: center.x, y: center.y + (pose == .proud ? -8 : 3)))
            context.stroke(arc, with: .color(dark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            return
        }

        let look: CGSize
        switch pose {
        case .curious: look = CGSize(width: 3.5, height: -3.5)
        case .sad: look = CGSize(width: 0, height: 4)
        case .tongue: look = CGSize(width: 5, height: 1)
        default: look = animating ? CGSize(width: sin(t * 0.7) * 3, height: cos(t * 0.5) * 1.5) : CGSize(width: 2, height: 0)
        }
        let pupil = CGPoint(x: center.x + look.width, y: center.y + look.height)
        context.fill(Path(ellipseIn: CGRect(x: pupil.x - 7, y: pupil.y - 7, width: 14, height: 14)), with: .color(dark))
        context.fill(Path(ellipseIn: CGRect(x: pupil.x - 4.5, y: pupil.y - 5, width: 4.5, height: 4.5)), with: .color(.white))

        if pose == .sad {
            // Paupière tombante.
            var lid = Path()
            lid.addArc(center: center, radius: 13.5, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            lid.closeSubpath()
            context.fill(lid, with: .color(skin))
            context.fill(lid, with: .color(.black.opacity(0.08)))
        }
    }

    private func drawMouth(_ context: inout GraphicsContext, t: Double, animating: Bool) {
        let left = CGPoint(x: 92, y: 60)
        let right = CGPoint(x: 104, y: 56)
        switch pose {
        case .proud:
            var mouth = Path()
            mouth.move(to: left)
            mouth.addQuadCurve(to: right, control: CGPoint(x: 99, y: 70))
            mouth.closeSubpath()
            context.fill(mouth, with: .color(dark))
            context.fill(Path(ellipseIn: CGRect(x: 95, y: 61.5, width: 6, height: 3.5)), with: .color(Color.blush))
        case .sad:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 93, y: 62))
            mouth.addQuadCurve(to: CGPoint(x: 103, y: 60), control: CGPoint(x: 98, y: 55))
            context.stroke(mouth, with: .color(dark), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case .tongue:
            var mouth = Path()
            mouth.move(to: left)
            mouth.addQuadCurve(to: right, control: CGPoint(x: 99, y: 64))
            context.stroke(mouth, with: .color(dark), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            // Langue qui jaillit, attrape, revient.
            let reach = animating ? tongueReach(t) : 0.7
            guard reach > 0.02 else { return }
            let tip = CGPoint(x: right.x + 14 * reach, y: right.y - 5 * reach)
            var tongue = Path()
            tongue.move(to: right)
            tongue.addLine(to: tip)
            context.stroke(tongue, with: .color(Color.blush), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: tip.x - 4.5, y: tip.y - 4.5, width: 9, height: 9)), with: .color(Color.blush))
        default:
            var mouth = Path()
            mouth.move(to: left)
            mouth.addQuadCurve(to: right, control: CGPoint(x: 99, y: 64))
            context.stroke(mouth, with: .color(dark), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
    }

    /// 0 → 1 → 0 en ~0,7 s, puis pause ; répété toutes les 2,6 s.
    private func tongueReach(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: 2.6)
        switch p {
        case ..<0.15: return p / 0.15
        case ..<0.5: return 1
        case ..<0.7: return 1 - (p - 0.5) / 0.2
        default: return 0
        }
    }

    private func drawSparkles(_ context: inout GraphicsContext, t: Double, animating: Bool) {
        for (i, spot) in [CGPoint(x: 60, y: 14), CGPoint(x: 112, y: 18), CGPoint(x: 118, y: 44)].enumerated() {
            let pulse = animating ? 0.6 + 0.4 * sin(t * 4 + Double(i) * 2) : 1
            let r = 5.0 * pulse
            var star = Path()
            star.move(to: CGPoint(x: spot.x, y: spot.y - r))
            star.addQuadCurve(to: CGPoint(x: spot.x + r, y: spot.y), control: spot)
            star.addQuadCurve(to: CGPoint(x: spot.x, y: spot.y + r), control: spot)
            star.addQuadCurve(to: CGPoint(x: spot.x - r, y: spot.y), control: spot)
            star.addQuadCurve(to: CGPoint(x: spot.x, y: spot.y - r), control: spot)
            context.fill(star, with: .color(Color.sun))
        }
    }
}

/// Léon qui parle : le caméléon et sa bulle.
struct LeonSays: View {
    let text: String
    var color: Color = .brand
    var pose: Leon.Pose = .wave
    var curl: Double = 0.4
    var size: CGFloat = 96

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            Leon(color: color, pose: pose, curl: curl).frame(width: size)
            SpeechBubble(text: text)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            Leon(color: .brand, pose: .wave)
            Leon(color: DomainPalette.color("geography"), pose: .tongue)
        }
        HStack(spacing: 16) {
            Leon(pose: .proud, curl: 1, rainbow: true)
            Leon(pose: .sad)
        }
        LeonSays(text: "Ton 5 du jour t'attend !")
    }
    .padding()
    .background(Color.paper)
}

/// Tenue de Léon : un objet (identifiant serveur) par emplacement.
struct LeonOutfit: Equatable, Sendable {
    var hat: String?
    var eyes: String?
    var neck: String?
    var back: String?
    var skin: String?

    init(hat: String? = nil, eyes: String? = nil, neck: String? = nil, back: String? = nil, skin: String? = nil) {
        self.hat = hat
        self.eyes = eyes
        self.neck = neck
        self.back = back
        self.skin = skin
    }

    init(_ slots: [String: String]) {
        self.init(hat: slots["hat"], eyes: slots["eyes"], neck: slots["neck"], back: slots["back"], skin: slots["skin"])
    }

    /// Même tenue avec un objet essayé à sa place.
    func trying(_ item: String, slot: String) -> LeonOutfit {
        var copy = self
        switch slot {
        case "hat": copy.hat = item
        case "eyes": copy.eyes = item
        case "neck": copy.neck = item
        case "back": copy.back = item
        case "skin": copy.skin = item
        default: break
        }
        return copy
    }
}

extension EnvironmentValues {
    /// Tenue du joueur, posée à la racine de l'app : Léon la porte partout.
    @Entry var leonOutfit = LeonOutfit()
}

/// Les objets de Léon, dessinés dans le même repère 128 × 96 que lui (tête centrée en (86, 46), rayon 24 ; œil en (90, 40)).
enum LeonWear {
    private static let dark = Color(hex: 0x1A1830)

    static func skinColor(_ id: String?) -> Color? {
        switch id {
        case "skin_sunset": return Color(hex: 0xFF8A5B)
        case "skin_gold": return Color(hex: 0xE8B923)
        default: return nil
        }
    }

    static func hat(_ id: String?, in context: inout GraphicsContext) {
        switch id {
        case "beret":
            var beret = Path(ellipseIn: CGRect(x: 71, y: 11, width: 36, height: 14))
            beret.addEllipse(in: CGRect(x: 76, y: 17, width: 26, height: 8))
            context.fill(beret, with: .color(Color(hex: 0xC92A2A)))
            context.fill(Path(ellipseIn: CGRect(x: 71, y: 11, width: 36, height: 8)), with: .color(.white.opacity(0.12)))
            context.fill(Path(ellipseIn: CGRect(x: 87, y: 7.5, width: 5, height: 5)), with: .color(Color(hex: 0xA61E1E)))
        case "party_hat":
            var cone = Path()
            cone.move(to: CGPoint(x: 79, y: 25))
            cone.addLine(to: CGPoint(x: 101, y: 22))
            cone.addLine(to: CGPoint(x: 91, y: 0))
            cone.closeSubpath()
            context.fill(cone, with: .color(Color(hex: 0x4DABF7)))
            context.drawLayer { layer in
                layer.clip(to: cone)
                for y in stride(from: 4.0, through: 24, by: 6) {
                    layer.fill(Path(CGRect(x: 76, y: y, width: 30, height: 2.4)), with: .color(Color.sun))
                }
            }
            context.fill(Path(ellipseIn: CGRect(x: 87.5, y: -3.5, width: 7, height: 7)), with: .color(Color(hex: 0xF06595)))
        case "headphones":
            var band = Path()
            band.move(to: CGPoint(x: 65, y: 42))
            band.addQuadCurve(to: CGPoint(x: 111, y: 40), control: CGPoint(x: 87, y: 0))
            context.stroke(band, with: .color(Color(hex: 0x343A40)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            for rect in [CGRect(x: 59, y: 36, width: 11, height: 17), CGRect(x: 106, y: 34, width: 11, height: 17)] {
                context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color(hex: 0xE64980)))
                context.fill(Path(roundedRect: rect.insetBy(dx: 2.5, dy: 3), cornerRadius: 3), with: .color(.white.opacity(0.25)))
            }
        case "leaf_crown":
            for (i, degrees) in stride(from: -158.0, through: -22, by: 17).enumerated() {
                let angle = degrees * .pi / 180
                let point = CGPoint(x: 86 + 25 * cos(angle), y: 46 + 25 * sin(angle))
                var leaf = Path(ellipseIn: CGRect(x: -6, y: -3, width: 12, height: 6))
                leaf = leaf.applying(CGAffineTransform(rotationAngle: angle + .pi / 2 + (i.isMultiple(of: 2) ? 0.5 : -0.5)))
                    .applying(CGAffineTransform(translationX: point.x, y: point.y))
                context.fill(leaf, with: .color(Color(hex: i.isMultiple(of: 2) ? 0x51CF66 : 0x2F9E44)))
            }
            for degrees in [-120.0, -90, -60] {
                let angle = degrees * .pi / 180
                let point = CGPoint(x: 86 + 27 * cos(angle), y: 46 + 27 * sin(angle))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(Color(hex: 0xFFD8A8)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 1.3, y: point.y - 1.3, width: 2.6, height: 2.6)), with: .color(Color.sun))
            }
        default:
            break
        }
    }

    static func eyes(_ id: String?, in context: inout GraphicsContext) {
        let center = CGPoint(x: 90, y: 40)
        switch id {
        case "round_glasses":
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)),
                           with: .color(dark), lineWidth: 2.6)
            var arm = Path()
            arm.move(to: CGPoint(x: center.x - 16, y: center.y - 1))
            arm.addLine(to: CGPoint(x: 64, y: 37))
            context.stroke(arm, with: .color(dark), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        case "star_glasses":
            var star = Path()
            for i in 0 ..< 10 {
                let radius = i.isMultiple(of: 2) ? 21.0 : 14.5
                let angle = -Double.pi / 2 + Double(i) * .pi / 5
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
            }
            star.closeSubpath()
            context.stroke(star, with: .color(Color(hex: 0xF06595)), style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))
        case "monocle":
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)),
                           with: .color(Color(hex: 0xE8B923)), lineWidth: 3)
            var chain = Path()
            chain.move(to: CGPoint(x: center.x + 9, y: center.y + 13))
            chain.addQuadCurve(to: CGPoint(x: 96, y: 76), control: CGPoint(x: 110, y: 66))
            context.stroke(chain, with: .color(Color(hex: 0xE8B923)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 2]))
        default:
            break
        }
    }

    static func neck(_ id: String?, in context: inout GraphicsContext) {
        switch id {
        case "red_scarf":
            var band = Path()
            band.move(to: CGPoint(x: 63, y: 57))
            band.addQuadCurve(to: CGPoint(x: 97, y: 66), control: CGPoint(x: 78, y: 74))
            context.stroke(band, with: .color(Color(hex: 0xE03131)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            let tail = Path(roundedRect: CGRect(x: -3.5, y: 0, width: 7, height: 15), cornerRadius: 3)
                .applying(CGAffineTransform(rotationAngle: 0.35).translatedBy(x: 0, y: 0))
                .applying(CGAffineTransform(translationX: 72, y: 65))
            context.fill(tail, with: .color(Color(hex: 0xC92A2A)))
            for x in [70.0, 80, 90] {
                context.fill(Path(CGRect(x: x, y: 62 + (x - 70) * 0.1, width: 2, height: 6)), with: .color(.white.opacity(0.3)))
            }
        case "bow_tie":
            let knot = CGPoint(x: 84, y: 71)
            for side in [-1.0, 1.0] {
                var wing = Path()
                wing.move(to: knot)
                wing.addLine(to: CGPoint(x: knot.x + 9 * side, y: knot.y - 6))
                wing.addLine(to: CGPoint(x: knot.x + 9 * side, y: knot.y + 6))
                wing.closeSubpath()
                context.fill(wing, with: .color(Color(hex: 0x7048E8)))
            }
            context.fill(Path(ellipseIn: CGRect(x: knot.x - 3, y: knot.y - 3, width: 6, height: 6)), with: .color(Color(hex: 0x5F3DC4)))
        default:
            break
        }
    }

    static func back(_ id: String?, in context: inout GraphicsContext, t: Double) {
        guard id == "star_cape" else { return }
        var cape = Path()
        cape.move(to: CGPoint(x: 66, y: 40))
        cape.addQuadCurve(to: CGPoint(x: 14, y: 84), control: CGPoint(x: 30, y: 44 + sin(t * 2) * 2))
        cape.addLine(to: CGPoint(x: 62, y: 84))
        cape.closeSubpath()
        context.fill(cape, with: .color(Color(hex: 0x364FC7)))
        for (x, y) in [(30.0, 70.0), (44, 60), (40, 78), (22, 80), (54, 70)] {
            context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)), with: .color(Color.sun))
        }
    }
}
