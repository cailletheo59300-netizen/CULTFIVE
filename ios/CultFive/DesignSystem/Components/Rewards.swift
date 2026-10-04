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

/// Les autres icônes 3D de l'app (même fabrication que les coffres).
enum GameIcon: String {
    case seeds, flame, joker
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
struct LeonTreeView: View {
    let stage: Int
    var fruits = 0
    /// Scène de l'écran Léon : sans butte (le sol est posé par l'écran), les petites étapes agrandies pour remplir le cadre.
    var scene = false

    var body: some View {
        Canvas { context, size in
            TreeDrawing(stage: stage, fruits: fruits, scene: scene).draw(in: &context, size: size)
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

    private let leaf = Color(hex: 0x40C057)
    private let leafDark = Color(hex: 0x2F9E44)
    private let leafLight = Color(hex: 0x8CE99A)
    private let bark = Color(hex: 0x8D5B3A)

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
        } else {
            // Butte de terre et herbe.
            context.fill(Path(ellipseIn: CGRect(x: 28, y: 164, width: 144, height: 30)), with: .color(Color(hex: 0xA47551)))
            context.fill(Path(ellipseIn: CGRect(x: 34, y: 160, width: 132, height: 16)), with: .color(Color(hex: 0x69DB7C)))
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

    private func seed(_ context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: 92, y: 158, width: 16, height: 11)), with: .color(Color(hex: 0x7A4B2A)))
        context.fill(Path(ellipseIn: CGRect(x: 96, y: 159, width: 6, height: 3)), with: .color(.white.opacity(0.3)))
        var shoot = Path()
        shoot.move(to: CGPoint(x: 100, y: 159))
        shoot.addQuadCurve(to: CGPoint(x: 104, y: 150), control: CGPoint(x: 99, y: 152))
        context.stroke(shoot, with: .color(leaf), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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
            var leafPath = Path(ellipseIn: CGRect(x: 0, y: -6, width: 22, height: 12))
            leafPath = leafPath
                .applying(CGAffineTransform(rotationAngle: side < 0 ? .pi + 0.5 : -0.5))
                .applying(CGAffineTransform(translationX: 100, y: y))
            context.fill(leafPath, with: .color(i < 2 ? leaf : leafDark))
        }
    }

    private func trunk(_ context: inout GraphicsContext, top: Double, width: Double) {
        var trunk = Path()
        trunk.move(to: CGPoint(x: 100 - width, y: 168))
        trunk.addLine(to: CGPoint(x: 100 - width * 0.45, y: top))
        trunk.addLine(to: CGPoint(x: 100 + width * 0.45, y: top))
        trunk.addLine(to: CGPoint(x: 100 + width, y: 168))
        trunk.closeSubpath()
        context.fill(trunk, with: .color(bark))
        context.fill(Path(CGRect(x: 100 - width * 0.2, y: top + 10, width: 2, height: 168 - top - 20)), with: .color(.black.opacity(0.12)))
    }

    private func bush(_ context: inout GraphicsContext) {
        trunk(&context, top: 118, width: 7)
        blob(&context, 78, 122, 22, leafDark)
        blob(&context, 122, 122, 22, leafDark)
        blob(&context, 100, 108, 28, leaf)
        blob(&context, 92, 100, 9, leafLight.opacity(0.7))
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
        for (x, y, r, color) in [(62.0, 8.0, 26.0, leafDark), (138, 8, 26, leafDark), (74, -18, 30, leaf),
                                  (126, -18, 30, leaf), (100, -34, 34, leaf), (100, 4, 32, leaf)] {
            blob(&context, 100 + (x - 100) * k, cy + y * k, r * k, color)
        }
        blob(&context, 86, cy - 36 * k, 11 * k, leafLight.opacity(0.6))
        if big {
            // Fleurs.
            for (x, y) in [(64.0, 62.0), (84, 36), (118, 30), (140, 66), (100, 58), (76, 84), (126, 86), (106, 20), (56, 88), (146, 90)] {
                blob(&context, x, y, 5, Color(hex: 0xFCC2D7))
                blob(&context, x, y, 2, Color.sun)
            }
        }
        // Fruits dorés.
        let spots: [(Double, Double)] = [(80, 70), (122, 56), (100, 92), (138, 80)]
        for (x, y) in spots.prefix(fruits) {
            blob(&context, x, y, 8, Color(hex: 0xF59F00))
            blob(&context, x, y, 7, Color(hex: 0xFFD43B))
            blob(&context, x - 2.5, y - 2.5, 2.2, .white.opacity(0.7))
            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: y - 7))
            stalk.addLine(to: CGPoint(x: x + 2, y: y - 11))
            context.stroke(stalk, with: .color(Color(hex: 0x5C3A1A)), lineWidth: 1.6)
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

/// Pastille de l'accueil : nombre de coffres à ouvrir.
struct ChestPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ChestView(tier: .gold).frame(width: 26, height: 22)
                Text("\(count)").monospacedDigit()
            }
            .font(.cfNumber)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.sun.opacity(0.35), in: Capsule())
        }
        .buttonStyle(.row)
        .accessibilityLabel(count > 1 ? "\(count) coffres à ouvrir" : "Un coffre à ouvrir")
    }
}
