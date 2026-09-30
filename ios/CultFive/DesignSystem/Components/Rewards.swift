import SwiftUI
import CultFiveCore

// MARK: - Coffre

/// Coffre dessiné en code : bois, argent ou or. Ouvert, le couvercle bascule et une lueur sort.
struct ChestView: View {
    let tier: ChestTier
    var open = false

    var body: some View {
        Canvas { context, size in
            ChestDrawing(tier: tier, open: open).draw(in: &context, size: size)
        }
        .aspectRatio(100.0 / 90.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(tier.title + (open ? ", ouvert" : ""))
    }
}

private struct ChestDrawing {
    let tier: ChestTier
    let open: Bool

    private var palette: (main: Color, dark: Color, band: Color) {
        switch tier {
        case .wood: return (Color(hex: 0xB7793E), Color(hex: 0x8A5A2B), Color(hex: 0x5F666D))
        case .silver: return (Color(hex: 0xDDE3EA), Color(hex: 0xAEB7C2), Color(hex: 0x6F7B88))
        case .gold: return (Color(hex: 0xFFC933), Color(hex: 0xE0A300), Color(hex: 0xA8740A))
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 100, size.height / 90)
        context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 90 * scale) / 2)
        context.scaleBy(x: scale, y: scale)
        let p = palette

        // Ombre.
        context.fill(Path(ellipseIn: CGRect(x: 14, y: 80, width: 72, height: 8)), with: .color(.black.opacity(0.1)))

        if open {
            // Lueur, puis couvercle basculé derrière.
            context.fill(Path(ellipseIn: CGRect(x: 6, y: 0, width: 88, height: 60)),
                         with: .radialGradient(Gradient(colors: [Color.sun.opacity(0.95), Color.sun.opacity(0)]),
                                               center: CGPoint(x: 50, y: 40), startRadius: 2, endRadius: 46))
            var lid = Path()
            lid.move(to: CGPoint(x: 12, y: 40))
            lid.addLine(to: CGPoint(x: 18, y: 14))
            lid.addQuadCurve(to: CGPoint(x: 82, y: 14), control: CGPoint(x: 50, y: 2))
            lid.addLine(to: CGPoint(x: 88, y: 40))
            lid.closeSubpath()
            context.fill(lid, with: .color(p.dark))
            context.fill(Path(roundedRect: CGRect(x: 16, y: 36, width: 68, height: 6), cornerRadius: 2), with: .color(Color(hex: 0x2B1A0E).opacity(0.55)))
        }

        // Caisse.
        let base = Path(roundedRect: CGRect(x: 10, y: 42, width: 80, height: 42), cornerRadius: 7)
        context.fill(base, with: .color(p.main))
        context.fill(Path(roundedRect: CGRect(x: 10, y: 70, width: 80, height: 14), cornerRadius: 7), with: .color(p.dark.opacity(0.55)))
        for x in [22.0, 72.0] {
            context.fill(Path(CGRect(x: x, y: 42, width: 6, height: 42)), with: .color(p.band))
        }
        if tier == .wood {
            for y in [54.0, 66.0] {
                context.fill(Path(CGRect(x: 12, y: y, width: 76, height: 1.2)), with: .color(p.dark.opacity(0.6)))
            }
        }

        if !open {
            // Couvercle bombé.
            var lid = Path()
            lid.move(to: CGPoint(x: 8, y: 44))
            lid.addLine(to: CGPoint(x: 8, y: 32))
            lid.addQuadCurve(to: CGPoint(x: 92, y: 32), control: CGPoint(x: 50, y: 6))
            lid.addLine(to: CGPoint(x: 92, y: 44))
            lid.closeSubpath()
            context.fill(lid, with: .color(p.main))
            context.fill(Path(ellipseIn: CGRect(x: 26, y: 16, width: 30, height: 8)), with: .color(.white.opacity(0.25)))
            context.drawLayer { layer in
                layer.clip(to: lid)
                for x in [22.0, 72.0] { layer.fill(Path(CGRect(x: x, y: 0, width: 6, height: 44)), with: .color(p.band)) }
            }
            context.fill(Path(CGRect(x: 8, y: 42, width: 84, height: 4)), with: .color(p.band))
        }

        // Serrure.
        let lock = Path(roundedRect: CGRect(x: 43, y: open ? 44 : 38, width: 14, height: 15), cornerRadius: 3)
        context.fill(lock, with: .color(p.band))
        context.fill(Path(ellipseIn: CGRect(x: 48, y: (open ? 44 : 38) + 4, width: 4, height: 4)), with: .color(Color(hex: 0x1A1830).opacity(0.7)))
        if tier == .gold {
            for (x, y) in [(18.0, 50.0), (84.0, 58.0)] {
                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
            }
        }
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
        }
    }
}

/// « 2 coffres t'attendent » : le plus beau coffre dessiné, bouton « Ouvrir ».
struct ChestsWaitingCard: View {
    let count: Int
    let tier: ChestTier
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ChestView(tier: tier).frame(width: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(count > 1 ? "\(count) coffres t'attendent" : "Un coffre t'attend")
                        .font(.cfTitle3).foregroundStyle(Color.ink)
                    Text("Graines, tickets d'aide, jokers, objets pour Léon…")
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
}

/// Pastille de l'accueil : nombre de coffres à ouvrir.
struct ChestPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ChestView(tier: .gold).frame(width: 22)
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
