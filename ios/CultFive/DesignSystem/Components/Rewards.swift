import SwiftUI
import CultFiveCore

// MARK: - Coffre

/// Coffre en 3D (bois, argent, or, Savant), fermé ou ouvert avec sa lueur. Images rendues à partir des modèles 3D
/// (`scripts/icons`), nettes à toutes les tailles.
struct ChestView: View {
    let tier: ChestTier
    var open = false

    var body: some View {
        Image("chest_\(tier.rawValue)" + (open ? "_open" : ""))
            .resizable()
            .scaledToFit()
            .accessibilityElement()
            .accessibilityLabel(tier.title + (open ? ", ouvert" : ""))
    }
}

/// Emblème 3D d'un rang d'Elo (Curieux : cercle, un trait … Encyclopédie : étoile couronnée).
struct RankEmblem: View {
    let rank: CoteCULT.Rank

    var body: some View {
        Image("rank_\(String(describing: rank))")
            .resizable()
            .scaledToFit()
            .accessibilityElement()
            .accessibilityLabel("Rang \(rank.name)")
    }
}

/// Les autres icônes 3D de l'app (même fabrication que les coffres).
enum GameIcon: String {
    case seeds, flame, joker, bag
    case flameOff = "flame_off"
    case ticketFifty = "ticket_fifty"
    case ticketHint = "ticket_hint"
    case wateringCan = "watering_can"

    var image: some View {
        Image(rawValue).resizable().scaledToFit().accessibilityHidden(true)
    }
}

// MARK: - Arbre de Léon

/// L'arbre de Léon, dessiné en code : graine, pousse, jeune plant, arbuste, arbre, arbre en fleurs ; puis ses fruits dorés.
/// Feuillage en volume (ombre et reflet), tronc à racines. Avec `time`, il se balance doucement.
struct LeonTreeView: View {
    let stage: Int
    var fruits = 0
    /// Scène de l'écran Léon : sans butte (le sol est posé par l'écran), les petites étapes agrandies pour remplir le cadre.
    var scene = false
    /// Temps de l'animation (balancement, fruits, fleurs) ; nil : dessin fixe.
    var time: Double? = nil

    var body: some View {
        Canvas { context, size in
            TreeDrawing(stage: stage, fruits: fruits, scene: scene, time: time ?? 0, animated: time != nil)
                .draw(in: &context, size: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(TreeState.stageName(stage) + (fruits > 0 ? ", \(fruits) fruit\(fruits > 1 ? "s" : "")" : ""))
    }
}

private struct TreeDrawing {
    let stage: Int
    let fruits: Int
    var scene = false
    var time: Double = 0
    var animated = false

    private let leaf = Color(hex: 0x40C057)
    private let leafDark = Color(hex: 0x2F9E44)
    private let leafDeep = Color(hex: 0x2B8A3E)
    private let leafLight = Color(hex: 0x8CE99A)
    private let bark = Color(hex: 0x8D5B3A)
    private let barkDark = Color(hex: 0x6E4529)

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width, size.height) / 200
        context.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 200 * scale) / 2)
        context.scaleBy(x: scale, y: scale)

        if scene {
            // Le pied de l'arbre reste au sol (y = 168) ; les petites étapes sont agrandies.
            let zoom: Double = [2.3, 2.1, 1.6, 1.25, 1.05, 1][min(max(stage, 1), 6) - 1]
            context.translateBy(x: 100, y: 168)
            context.scaleBy(x: zoom, y: zoom)
            context.translateBy(x: -100, y: -168)
            // Ombre au sol.
            let w: Double = [14.0, 18, 26, 44, 56, 64][min(max(stage, 1), 6) - 1]
            ellipse(&context, 100, 169, w, 5, Color(hex: 0x1E3C1E).opacity(0.18))
        } else {
            // Butte de terre et herbe.
            context.fill(Path(ellipseIn: CGRect(x: 28, y: 164, width: 144, height: 30)), with: .color(Color(hex: 0xA47551)))
            context.fill(Path(ellipseIn: CGRect(x: 34, y: 160, width: 132, height: 16)), with: .color(Color(hex: 0x69DB7C)))
        }
        // Balancement léger, depuis le pied.
        if animated {
            let sway: Double = sin(time * 1.3) * 0.012
            context.translateBy(x: 100, y: 168)
            context.rotate(by: .radians(sway))
            context.translateBy(x: -100, y: -168)
        }

        switch stage {
        case ...1: seed(&context)
        case 2: sprout(&context, height: 26, leaves: 2)
        case 3: sprout(&context, height: 48, leaves: 4)
        case 4: bush(&context)
        case 5: tree(&context, big: false)
        default: tree(&context, big: true)
        }
    }

    private func blob(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }

    private func ellipse(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry)), with: .color(color))
    }

    /// Boule de feuillage en volume : base, ombre en bas, reflet en haut (toujours plat, style Pop).
    private func leafBall(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double,
                          base: Color, dark: Color, light: Color) {
        let ball = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        context.fill(ball, with: .color(base))
        context.drawLayer { layer in
            layer.clip(to: ball)
            let sr: Double = r * 0.95
            layer.fill(Path(ellipseIn: CGRect(x: x + r * 0.15 - sr, y: y + r * 0.55 - sr, width: 2 * sr, height: 2 * sr)), with: .color(dark))
        }
        blob(&context, x - r * 0.3, y - r * 0.35, r * 0.28, light)
    }

    private func seed(_ context: inout GraphicsContext) {
        ellipse(&context, 100, 163.5, 8, 5.5, Color(hex: 0x7A4B2A))
        ellipse(&context, 97, 161, 3, 1.5, .white.opacity(0.35))
        var shoot = Path()
        shoot.move(to: CGPoint(x: 100, y: 159))
        shoot.addQuadCurve(to: CGPoint(x: 104, y: 150), control: CGPoint(x: 99, y: 152))
        context.stroke(shoot, with: .color(leaf), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        let tip = Path(ellipseIn: CGRect(x: -4, y: -2.2, width: 8, height: 4.4))
            .applying(CGAffineTransform(rotationAngle: -0.5))
            .applying(CGAffineTransform(translationX: 106, y: 149))
        context.fill(tip, with: .color(leaf))
    }

    private func sprout(_ context: inout GraphicsContext, height: Double, leaves: Int) {
        let top = 166 - height
        var stem = Path()
        stem.move(to: CGPoint(x: 100, y: 166))
        stem.addQuadCurve(to: CGPoint(x: 100, y: top), control: CGPoint(x: 96, y: 166 - height / 2))
        context.stroke(stem, with: .color(leafDark), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        for i in 0 ..< leaves {
            let y = top + Double(i / 2) * 18 + 4
            let side: Double = i.isMultiple(of: 2) ? -1 : 1
            let flutter: Double = animated ? sin(time * 2 + Double(i)) * 0.06 : 0
            let angle: Double = (side < 0 ? .pi + 0.5 : -0.5) + flutter
            let transform = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: 100, y: y))
            context.fill(Path(ellipseIn: CGRect(x: 0, y: -6, width: 22, height: 12)).applying(transform), with: .color(i < 2 ? leaf : leafDark))
            var vein = Path()
            vein.move(to: CGPoint(x: 2, y: 0))
            vein.addLine(to: CGPoint(x: 18, y: 0))
            context.stroke(vein.applying(transform), with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        ellipse(&context, 100, top - 2, 4, 3, leafLight)
    }

    private func trunk(_ context: inout GraphicsContext, top: Double, width: Double) {
        var trunk = Path()
        trunk.move(to: CGPoint(x: 100 - width, y: 168))
        trunk.addQuadCurve(to: CGPoint(x: 100 - width * 0.45, y: top), control: CGPoint(x: 100 - width * 0.5, y: 140))
        trunk.addLine(to: CGPoint(x: 100 + width * 0.45, y: top))
        trunk.addQuadCurve(to: CGPoint(x: 100 + width, y: 168), control: CGPoint(x: 100 + width * 0.5, y: 140))
        trunk.closeSubpath()
        context.fill(trunk, with: .color(bark))
        // Côté à l'ombre.
        context.drawLayer { layer in
            layer.clip(to: trunk)
            layer.fill(Path(CGRect(x: 100 + width * 0.15, y: top, width: width, height: 168 - top)), with: .color(barkDark))
        }
        // Racines.
        ellipse(&context, 100 - width - 2, 167, 5, 2.5, bark)
        ellipse(&context, 100 + width + 2, 167, 5, 2.5, barkDark)
        var line = Path()
        line.move(to: CGPoint(x: 100 - width * 0.25, y: top + 12))
        line.addLine(to: CGPoint(x: 100 - width * 0.3, y: 160))
        context.stroke(line, with: .color(.black.opacity(0.15)), lineWidth: 1.5)
    }

    private func bush(_ context: inout GraphicsContext) {
        trunk(&context, top: 118, width: 7)
        leafBall(&context, 78, 122, 22, base: leafDark, dark: leafDeep, light: leaf)
        leafBall(&context, 122, 122, 22, base: leafDark, dark: leafDeep, light: leaf)
        leafBall(&context, 100, 106, 28, base: leaf, dark: leafDark, light: leafLight)
    }

    private func tree(_ context: inout GraphicsContext, big: Bool) {
        let k = big ? 1.18 : 1.0
        trunk(&context, top: big ? 92 : 104, width: big ? 13 : 10)
        // Branches.
        for (dx, dy) in [(-24.0, -14.0), (22.0, -18.0)] {
            var branch = Path()
            branch.move(to: CGPoint(x: 100, y: big ? 112 : 120))
            branch.addLine(to: CGPoint(x: 100 + dx * k, y: (big ? 112 : 120) + dy * k))
            context.stroke(branch, with: .color(bark), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        let cy = big ? 72.0 : 84.0
        let balls: [(Double, Double, Double, Bool)] = [(62, 8, 26, false), (138, 8, 26, false), (74, -18, 30, true),
                                                       (126, -18, 30, true), (100, -34, 34, true), (100, 4, 32, true)]
        for (x, y, r, light) in balls {
            leafBall(&context, 100 + (x - 100) * k, cy + y * k, r * k,
                     base: light ? leaf : leafDark, dark: light ? leafDark : leafDeep, light: light ? leafLight : leaf)
        }
        if big {
            // Fleurs à cinq pétales.
            let spin: Double = animated ? time * 0.3 : 0
            for (x, y) in [(64.0, 62.0), (84, 36), (118, 30), (140, 66), (100, 58), (76, 84), (126, 86), (106, 20), (56, 88), (146, 90)] {
                for p in 0 ..< 5 {
                    let a: Double = Double(p) / 5 * 2 * .pi + spin
                    blob(&context, x + cos(a) * 3.2, y + sin(a) * 3.2, 2.6, Color(hex: 0xFCC2D7))
                }
                blob(&context, x, y, 2, Color.sun)
            }
        }
        // Fruits dorés, qui bougent un peu.
        let spots: [(Double, Double)] = [(80, 70), (122, 56), (100, 92), (138, 80)]
        for (i, spot) in spots.prefix(fruits).enumerated() {
            let x = spot.0
            let y: Double = spot.1 + (animated ? sin(time * 2 + Double(i)) * 1.2 : 0)
            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: y - 7))
            stalk.addLine(to: CGPoint(x: x + 2, y: y - 11))
            context.stroke(stalk, with: .color(Color(hex: 0x5C3A1A)), lineWidth: 1.6)
            blob(&context, x, y, 8, Color(hex: 0xF59F00))
            blob(&context, x - 0.6, y - 0.6, 7, Color(hex: 0xFFD43B))
            blob(&context, x - 2.5, y - 2.5, 2.2, .white.opacity(0.75))
            let leafPath = Path(ellipseIn: CGRect(x: -3.5, y: -1.8, width: 7, height: 3.6))
                .applying(CGAffineTransform(rotationAngle: -0.4))
                .applying(CGAffineTransform(translationX: x + 4, y: y - 10))
            context.fill(leafPath, with: .color(leaf))
        }
    }
}

extension ChestTier {
    /// Ordre de valeur (bois < argent < or).
    var rank: Int {
        switch self {
        case .wood: return 0
        case .silver: return 1
        case .gold: return 2
        case .savant: return 3
        }
    }
}

/// « 3 coffres t'attendent » : les plus beaux coffres empilés (le meilleur devant), bouton « Ouvrir ».
struct ChestsWaitingCard: View {
    let tiers: [ChestTier]
    let action: () -> Void

    private var count: Int { tiers.count }
    /// Jusqu'à trois coffres, du plus beau au moins beau.
    private var shown: [ChestTier] { Array(tiers.sorted { $0.rank > $1.rank }.prefix(3)) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    // Derrière : les suivants, un peu plus petits, de part et d'autre.
                    ForEach(Array(shown.enumerated().reversed()), id: \.offset) { i, tier in
                        ChestView(tier: tier)
                            .frame(width: i == 0 ? 58 : 44)
                            .offset(x: i == 0 ? 0 : (i == 1 ? 18 : -18), y: i == 0 ? 0 : 6)
                    }
                }
                .frame(width: shown.count > 1 ? 82 : 58, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(count > 1 ? "\(count) coffres t'attendent" : "Un coffre t'attend")
                        .font(.cfTitle3).foregroundStyle(Color.ink)
                    Text(count > 1 ? detail : "Graines, tickets d'aide, jokers, objets pour Léon…")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 0)
                Text("Ouvrir")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color(hex: 0x1E1340))
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(Color.sun, in: Capsule())
            }
            .popCard(padding: 14)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .combine)
    }

    /// « 1 en or, 2 en bois ».
    private var detail: String {
        let names: [(ChestTier, String)] = [(.savant, "Savant"), (.gold, "en or"), (.silver, "en argent"), (.wood, "en bois")]
        return names.compactMap { tier, name in
            let n = tiers.filter { $0 == tier }.count
            return n > 0 ? "\(n) \(name)" : nil
        }
        .joined(separator: ", ")
    }
}
