import SwiftUI

/// Proportions d'une carte de l'album (300 × 419).
let albumCardRatio: CGFloat = 300.0 / 419.0

/// Une carte de l'album dans son état : normale, brillante, Prestige, Chef-d'œuvre, avec son habillage.
/// `tilt` (−1…1) fait bouger les reflets : glisser le doigt ou incliner le téléphone sur la fiche.
struct AlbumCardView: View {
    let card: AlbumCard
    var state: OwnedCard?
    var tilt: CGSize = .zero
    /// Habillage et effets : coupés dans les petites vignettes si besoin.
    var dressed = true

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let radius = w * 0.06
            ZStack {
                if state?.prestige == true {
                    PrestigeFace(card: card, width: w, tilt: tilt)
                } else {
                    AlbumImage(kind: .faces, name: card.id)
                }
                if state?.shiny == true {
                    ShineLayer(tilt: tilt, strength: state?.prestige == true ? 0.5 : 0.75)
                }
                if dressed, let finish = state?.finish {
                    FinishLayer(kind: finish, tilt: tilt)
                }
                if state?.masterpiece == true {
                    MasterpieceFrame(width: w, tilt: tilt)
                }
                if dressed, let frame = state?.frame {
                    CardFrame(kind: frame, width: w)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .bottom) {
                if dressed, let title = state?.title, let item = Cosmetic.titles.first(where: { $0.id == title }) {
                    TitleRibbon(text: item.name, width: w)
                        .offset(y: w * 0.07)
                }
            }
        }
        .aspectRatio(albumCardRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [card.name, card.rarity.label]
        if state?.shiny == true { parts.append("brillante") }
        if state?.prestige == true { parts.append("Prestige") }
        if state?.masterpiece == true { parts.append("Chef-d'œuvre") }
        return parts.joined(separator: ", ")
    }
}

/// Carte vue de dos (dos choisi dans l'album).
struct AlbumCardBack: View {
    var kind = "classique"

    var body: some View {
        AlbumImage(kind: .backs, name: kind)
            .aspectRatio(albumCardRatio, contentMode: .fit)
    }
}

// MARK: - États

/// Prestige : le dessin occupe toute la carte, sur fond holographique ; textes posés automatiquement.
private struct PrestigeFace: View {
    let card: AlbumCard
    let width: CGFloat
    let tilt: CGSize

    var body: some View {
        let tone = DomainPalette.color(card.domain)
        ZStack {
            LinearGradient(colors: [tone.opacity(0.95), Color(hex: 0x1A1830)], startPoint: .top, endPoint: .bottom)
            AngularGradient(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xFFD23F), Color(hex: 0x3DDC97), Color(hex: 0x4A9BFF),
                                     Color(hex: 0xB66BFF), Color(hex: 0xFF8FB1)],
                            center: UnitPoint(x: 0.5 + tilt.width * 0.4, y: 0.35 + tilt.height * 0.3))
                .opacity(0.35)
                .blendMode(.screen)
            VStack(spacing: width * 0.02) {
                HStack {
                    Text(AlbumCatalog.shared.page(card.pageKey)?.title.uppercased() ?? "")
                        .font(.system(size: width * 0.04, weight: .heavy, design: .rounded))
                        .tracking(width * 0.006)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(card.n)")
                        .font(.system(size: width * 0.05, weight: .black, design: .serif))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, width * 0.07)
                .padding(.top, width * 0.07)
                AlbumImage(kind: .art, name: card.id)
                    .shadow(color: .black.opacity(0.35), radius: width * 0.03, y: width * 0.02)
                    .scaleEffect(1.12)
                    .offset(x: tilt.width * width * 0.015, y: tilt.height * width * 0.015)
                    .padding(.horizontal, width * 0.04)
                    .frame(maxHeight: .infinity)
                VStack(spacing: width * 0.01) {
                    Text(card.figure)
                        .font(.system(size: width * 0.14, weight: .black, design: .serif))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF1C2), Color(hex: 0xFFD23F)], startPoint: .top, endPoint: .bottom))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(card.name)
                        .font(.system(size: width * 0.065, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, width * 0.07)
                .padding(.bottom, width * 0.08)
            }
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xFFF1C2), Color(hex: 0xD9A441), Color(hex: 0xF6D98A)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width * 0.018)
                .padding(width * 0.025)
        }
    }
}

/// Reflet de la carte brillante : bande irisée qui glisse avec l'inclinaison.
private struct ShineLayer: View {
    let tilt: CGSize
    var strength: Double = 0.75

    var body: some View {
        GeometryReader { proxy in
            let shift = (tilt.width + tilt.height) * 0.5
            LinearGradient(stops: [
                .init(color: .clear, location: max(0, 0.25 + shift * 0.4)),
                .init(color: Color(hex: 0xFF8FB1).opacity(0.55), location: min(1, 0.38 + shift * 0.4)),
                .init(color: Color(hex: 0xFFF6C8).opacity(0.85), location: min(1, 0.46 + shift * 0.4)),
                .init(color: Color(hex: 0x7BE3FF).opacity(0.55), location: min(1, 0.54 + shift * 0.4)),
                .init(color: .clear, location: min(1, 0.68 + shift * 0.4)),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .blendMode(.overlay)
            .opacity(strength)
        }
        .allowsHitTesting(false)
    }
}

/// Finitions : Givre, Poussière d'or, Holographique.
private struct FinishLayer: View {
    let kind: String
    let tilt: CGSize

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: kind == "or" ? 11 : 23)
            switch kind {
            case "givre":
                for _ in 0..<70 {
                    let x = Double.random(in: 0..<1, using: &generator) * size.width
                    let y = Double.random(in: 0..<1, using: &generator) * size.height
                    let r = 1 + Double.random(in: 0..<1, using: &generator) * 2.4
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.75)))
                }
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(Gradient(colors: [Color(hex: 0xDDF4FF).opacity(0.45), .clear, Color(hex: 0xDDF4FF).opacity(0.35)]),
                                                   startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            case "or":
                for _ in 0..<55 {
                    let x = Double.random(in: 0..<1, using: &generator) * size.width
                    let y = Double.random(in: 0..<1, using: &generator) * size.height
                    let r = 1.2 + Double.random(in: 0..<1, using: &generator) * 2.2
                    let twinkle = 0.45 + 0.55 * abs(sin(x * 0.05 + Double(tilt.width) * 6 + Double(tilt.height) * 4))
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(Color(hex: 0xFFD23F).opacity(twinkle)))
                }
            default:
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(Gradient(colors: [Color(hex: 0xFF6A88), Color(hex: 0xF6C744), Color(hex: 0x3FD0A0),
                                                                     Color(hex: 0x4A9BFF), Color(hex: 0xB66BFF)]),
                                                   startPoint: CGPoint(x: size.width * (0.0 + tilt.width * 0.5), y: 0),
                                                   endPoint: CGPoint(x: size.width * (1.0 + tilt.width * 0.5), y: size.height)))
            }
        }
        .blendMode(kind == "holo" ? .overlay : .normal)
        .opacity(kind == "holo" ? 0.55 : 1)
        .allowsHitTesting(false)
    }
}

/// Chef-d'œuvre : triple cadre doré et plaque gravée (carte maîtrisée au quiz).
private struct MasterpieceFrame: View {
    let width: CGFloat
    let tilt: CGSize

    private var gold: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFF1C2), Color(hex: 0xD9A441), Color(hex: 0x9C6412), Color(hex: 0xF6D98A)],
                       startPoint: UnitPoint(x: 0 + tilt.width * 0.3, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.3, y: 1))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: width * (0.055 - Double(i) * 0.01), style: .continuous)
                    .strokeBorder(gold, lineWidth: width * (i == 0 ? 0.03 : 0.008))
                    .padding(width * (i == 0 ? 0 : 0.03 + Double(i) * 0.015))
            }
            Text("CHEF-D'ŒUVRE")
                .font(.system(size: width * 0.036, weight: .black, design: .serif))
                .tracking(width * 0.006)
                .foregroundStyle(Color(hex: 0x3A2408))
                .padding(.horizontal, width * 0.05)
                .padding(.vertical, width * 0.012)
                .background(gold, in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0x7A4A08), lineWidth: 0.8))
                .padding(.bottom, width * 0.012)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Habillage

/// Cadres posés par-dessus la carte.
struct CardFrame: View {
    let kind: String
    let width: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
        ZStack {
            switch kind {
            case "citrouille":
                shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xFF9A3C), Color(hex: 0xB8460A)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: width * 0.035)
                shape.strokeBorder(Color(hex: 0x2B1636), style: StrokeStyle(lineWidth: width * 0.008, dash: [width * 0.03, width * 0.02]))
                    .padding(width * 0.01)
            case "vitrail":
                shape.strokeBorder(AngularGradient(colors: [Color(hex: 0xE5383B), Color(hex: 0xFCC419), Color(hex: 0x37B24D),
                                                            Color(hex: 0x1C7ED6), Color(hex: 0x845EF7), Color(hex: 0xE5383B)], center: .center),
                                   lineWidth: width * 0.04)
                shape.strokeBorder(Color(hex: 0x1A1830), lineWidth: width * 0.008)
                shape.strokeBorder(Color(hex: 0x1A1830), lineWidth: width * 0.006).padding(width * 0.036)
            case "nuit":
                shape.strokeBorder(LinearGradient(colors: [Color(hex: 0x1B1A4A), Color(hex: 0x07061A)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: width * 0.04)
                shape.strokeBorder(Color(hex: 0xE9C566), lineWidth: width * 0.006).padding(width * 0.03)
                StarDust(width: width)
            case "toile":
                shape.strokeBorder(Color(hex: 0x2B2B33), lineWidth: width * 0.03)
                WebCorners(width: width)
            case "anime":
                AnimatedGoldFrame(width: width)
            default:
                shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xF4F1EA), Color(hex: 0xB9B4C4), Color(hex: 0xEDEAF2), Color(hex: 0x8D889B)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width * 0.04)
                shape.strokeBorder(Color.white.opacity(0.8), lineWidth: width * 0.005).padding(width * 0.035)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StarDust: View {
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 5)
            for _ in 0..<40 {
                let edge = Int.random(in: 0..<4, using: &generator)
                let t = Double.random(in: 0..<1, using: &generator)
                let inset = Double.random(in: 0..<1, using: &generator) * width * 0.035
                let point: CGPoint
                switch edge {
                case 0: point = CGPoint(x: t * size.width, y: inset)
                case 1: point = CGPoint(x: size.width - inset, y: t * size.height)
                case 2: point = CGPoint(x: t * size.width, y: size.height - inset)
                default: point = CGPoint(x: inset, y: t * size.height)
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.9)))
            }
        }
    }
}

private struct WebCorners: View {
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let r = width * 0.28
            for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0)] {
                let sx: CGFloat = corner.x == 0 ? 1 : -1
                var path = Path()
                for i in 0..<5 {
                    let a = Double(i) / 4 * .pi / 2
                    path.move(to: corner)
                    path.addLine(to: CGPoint(x: corner.x + sx * r * cos(a), y: r * sin(a)))
                }
                for ring in 1...3 {
                    let rr = r * Double(ring) / 3.4
                    for i in 0..<4 {
                        let a1 = Double(i) / 4 * .pi / 2, a2 = Double(i + 1) / 4 * .pi / 2
                        path.move(to: CGPoint(x: corner.x + sx * rr * cos(a1), y: rr * sin(a1)))
                        path.addQuadCurve(to: CGPoint(x: corner.x + sx * rr * cos(a2), y: rr * sin(a2)),
                                          control: CGPoint(x: corner.x + sx * rr * 0.75 * cos((a1 + a2) / 2), y: rr * 0.75 * sin((a1 + a2) / 2)))
                    }
                }
                context.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 0.8)
            }
        }
    }
}

/// Cadre animé (récompense finale du Pass+) : un liseré doré qui tourne.
private struct AnimatedGoldFrame: View {
    let width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360
            RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
                .strokeBorder(AngularGradient(colors: [Color(hex: 0x9C6412), Color(hex: 0xFFF1C2), Color(hex: 0xD9A441), Color(hex: 0x9C6412)],
                                              center: .center, angle: .degrees(angle)), lineWidth: width * 0.04)
        }
    }
}

/// Titre de carte : banderole sous la carte.
struct TitleRibbon: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: width * 0.05, weight: .heavy, design: .serif))
            .foregroundStyle(Color(hex: 0x3A2408))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, width * 0.08)
            .padding(.vertical, width * 0.02)
            .background(
                LinearGradient(colors: [Color(hex: 0xFFF1C2), Color(hex: 0xE9C566)], startPoint: .top, endPoint: .bottom),
                in: RibbonShape()
            )
            .overlay(RibbonShape().stroke(Color(hex: 0x9C6412), lineWidth: 1))
            .frame(maxWidth: width * 0.9)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }
}

private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.35
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Case vide

/// Pochette vide du classeur : silhouette du dessin, numéro et prix pour la fabriquer.
struct EmptySlot: View {
    let card: AlbumCard

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(Color.ink.opacity(0.04))
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .strokeBorder(Color.ink.opacity(0.14), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                VStack(spacing: w * 0.03) {
                    AlbumImage(kind: .art, name: card.id, template: true)
                        .foregroundStyle(Color.ink.opacity(0.13))
                        .padding(.horizontal, w * 0.08)
                    Text("\(card.n)")
                        .font(.system(size: w * 0.14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ink.opacity(0.25))
                    HStack(spacing: 3) {
                        Image(systemName: "brain.fill")
                        Text("\(card.rarity.craftCost)")
                    }
                    .font(.system(size: max(w * 0.085, 9), weight: .heavy, design: .rounded))
                    .foregroundStyle(card.rarity.color)
                }
            }
        }
        .aspectRatio(albumCardRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Case \(card.n) vide, \(card.rarity.label), à fabriquer pour \(card.rarity.craftCost) neurones")
    }
}

/// Montant de neurones (monnaie de l'album).
struct NeuronesAmount: View {
    let amount: Int
    var color: Color = .ink

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.fill").foregroundStyle(Color(hex: 0xF0588F))
            Text(amount.formatted(.number.locale(Locale(identifier: "fr_FR")))).monospacedDigit()
        }
        .font(.system(.subheadline, design: .rounded).weight(.heavy))
        .foregroundStyle(color)
        .accessibilityElement()
        .accessibilityLabel("\(amount) neurones")
    }
}
