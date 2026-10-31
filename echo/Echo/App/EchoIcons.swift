import SwiftUI

// Icônes propres à Écho, dessinées par le code dans le même style (dégradés lumineux, contours nets).
// Toutes prennent une taille en points ; aucune image à produire.

/// Pièce d'Écho : or bombé, double bord, et le symbole des échos (ondes) gravé au centre.
struct CoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#FFF6C2"), Color(hex: "#FFCB3D"), Color(hex: "#D98C0B")],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            Circle().strokeBorder(Color(hex: "#A86A06"), lineWidth: max(1, size * 0.07))
            Circle().strokeBorder(Color(hex: "#FFE89A").opacity(0.9), lineWidth: max(0.7, size * 0.035)).padding(size * 0.14)
            EchoWaves()
                .stroke(Color(hex: "#A86A06"), style: StrokeStyle(lineWidth: max(1, size * 0.075), lineCap: .round))
                .padding(size * 0.27)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#FFC93D").opacity(0.45), radius: size * 0.18)
    }
}

/// Symbole d'Écho : un point et deux ondes qui s'en éloignent.
struct EchoWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY)
        path.addEllipse(in: CGRect(x: origin.x - rect.width * 0.08, y: origin.y - rect.width * 0.08,
                                   width: rect.width * 0.16, height: rect.width * 0.16))
        let start: CGFloat = -48 * .pi / 180
        for radius in [rect.width * 0.45, rect.width * 0.8] {
            // Départ de l'onde, sans trait depuis le point central.
            path.move(to: CGPoint(x: origin.x + radius * cos(start), y: origin.y + radius * sin(start)))
            path.addArc(center: origin, radius: radius, startAngle: .degrees(-48), endAngle: .degrees(48), clockwise: false)
        }
        return path
    }
}

/// Tas de pièces, plus ou moins gros (packs de pièces).
struct CoinStack: View {
    /// 1 (petit), 2 (moyen) ou 3 (gros).
    let level: Int
    var size: CGFloat = 26

    private var offsets: [CGPoint] {
        switch level {
        case 1: [CGPoint(x: -0.25, y: 0.1), CGPoint(x: 0.25, y: 0.15), CGPoint(x: 0, y: -0.2)]
        case 2: [CGPoint(x: -0.5, y: 0.2), CGPoint(x: 0, y: 0.25), CGPoint(x: 0.5, y: 0.2),
                 CGPoint(x: -0.25, y: -0.15), CGPoint(x: 0.25, y: -0.12), CGPoint(x: 0, y: -0.5)]
        default: [CGPoint(x: -0.75, y: 0.3), CGPoint(x: -0.25, y: 0.35), CGPoint(x: 0.25, y: 0.35), CGPoint(x: 0.75, y: 0.3),
                  CGPoint(x: -0.5, y: -0.05), CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: -0.05),
                  CGPoint(x: -0.25, y: -0.4), CGPoint(x: 0.25, y: -0.38), CGPoint(x: 0, y: -0.78)]
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, point in
                CoinIcon(size: size).offset(x: point.x * size, y: point.y * size)
            }
        }
        .frame(width: size * 2.6, height: size * 2.2)
    }
}

/// Flamme de la série : deux couches en dégradé qui ondulent doucement.
struct FlameIcon: View {
    var size: CGFloat = 22
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                FlameShape()
                    .fill(LinearGradient(colors: [Color(hex: "#FF2E4D"), Color(hex: "#FF7A1A"), Color(hex: "#FFC93D")],
                                         startPoint: .top, endPoint: .bottom))
                FlameShape()
                    .fill(LinearGradient(colors: [Color(hex: "#FFE27A"), Color(hex: "#FFF8DC")], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.42, height: size * 0.5)
                    .offset(y: size * 0.2)
            }
            .frame(width: size * 0.82, height: size)
            .scaleEffect(x: 1 + 0.04 * sin(t * 11), y: 1 + 0.07 * sin(t * 8), anchor: .bottom)
            .rotationEffect(.degrees(2.5 * sin(t * 5)), anchor: .bottom)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#FF7A1A").opacity(0.6), radius: size * 0.2)
    }
}

struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX + w * 0.05, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.66),
                   control1: CGPoint(x: r.midX + w * 0.2, y: r.minY + h * 0.25), control2: CGPoint(x: r.maxX, y: r.minY + h * 0.38))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.88), control2: CGPoint(x: r.midX + w * 0.3, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.66),
                   control1: CGPoint(x: r.midX - w * 0.3, y: r.maxY), control2: CGPoint(x: r.minX, y: r.minY + h * 0.88))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.3),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.5), control2: CGPoint(x: r.minX + w * 0.08, y: r.minY + h * 0.38))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.36, y: r.minY + h * 0.52),
                   control1: CGPoint(x: r.minX + w * 0.24, y: r.minY + h * 0.42), control2: CGPoint(x: r.minX + w * 0.3, y: r.minY + h * 0.5))
        p.addCurve(to: CGPoint(x: r.midX + w * 0.05, y: r.minY),
                   control1: CGPoint(x: r.minX + w * 0.34, y: r.minY + h * 0.3), control2: CGPoint(x: r.midX - w * 0.05, y: r.minY + h * 0.18))
        p.closeSubpath()
        return p
    }
}

/// Coupe des classements.
struct TrophyIcon: View {
    var size: CGFloat = 24

    var body: some View {
        let gold = LinearGradient(colors: [Color(hex: "#FFF1A8"), Color(hex: "#FFC93D"), Color(hex: "#D98C0B")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        ZStack {
            TrophyHandles()
                .stroke(Color(hex: "#FFC93D"), style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            TrophyCup().fill(gold)
            Star4()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(x: -size * 0.08, y: -size * 0.16)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: "#FFC93D").opacity(0.5), radius: size * 0.15)
    }
}

struct TrophyCup: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        // Coupe.
        p.move(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.06))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.22, y: r.minY + h * 0.06))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.maxX - w * 0.2, y: r.minY + h * 0.42), control2: CGPoint(x: r.midX + w * 0.16, y: r.minY + h * 0.6))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.06),
                   control1: CGPoint(x: r.midX - w * 0.16, y: r.minY + h * 0.6), control2: CGPoint(x: r.minX + w * 0.2, y: r.minY + h * 0.42))
        // Pied et socle.
        p.addRect(CGRect(x: r.midX - w * 0.06, y: r.minY + h * 0.6, width: w * 0.12, height: h * 0.18))
        p.addRoundedRect(in: CGRect(x: r.midX - w * 0.25, y: r.minY + h * 0.78, width: w * 0.5, height: h * 0.14),
                         cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        return p
    }
}

struct TrophyHandles: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addArc(center: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.24), radius: w * 0.14,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.move(to: CGPoint(x: r.maxX - w * 0.22, y: r.minY + h * 0.1))
        p.addArc(center: CGPoint(x: r.maxX - w * 0.22, y: r.minY + h * 0.24), radius: w * 0.14,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        return p
    }
}

/// Calendrier du défi du jour, avec le numéro du jour.
struct CalendarIcon: View {
    let day: Int
    var size: CGFloat = 34

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#2A1650"), Color(hex: "#160A30")], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .strokeBorder(Theme.ghost, lineWidth: size * 0.05)
            UnevenRoundedRectangle(topLeadingRadius: size * 0.18, topTrailingRadius: size * 0.18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#FF6FB0"), Theme.ghost], startPoint: .top, endPoint: .bottom))
                .frame(height: size * 0.3)
            HStack(spacing: size * 0.3) {
                Capsule().fill(Color.white).frame(width: size * 0.08, height: size * 0.2)
                Capsule().fill(Color.white).frame(width: size * 0.08, height: size * 0.2)
            }
            .offset(y: -size * 0.08)
            Text("\(day)")
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.top, size * 0.34)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.ghost.opacity(0.5), radius: size * 0.15)
    }
}

/// Sac de la boutique avec une étincelle.
struct BagIcon: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            BagHandle()
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            BagBody()
                .fill(LinearGradient(colors: [Color(hex: "#FFE27A"), Color(hex: "#FFB23D")], startPoint: .top, endPoint: .bottom))
            Star4()
                .fill(Color.white)
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(y: size * 0.12)
            Star4()
                .fill(Theme.accent)
                .frame(width: size * 0.26, height: size * 0.26)
                .offset(x: size * 0.42, y: -size * 0.36)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.gold.opacity(0.5), radius: size * 0.15)
    }
}

struct BagBody: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX + w * 0.16, y: r.minY + h * 0.32))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.16, y: r.minY + h * 0.32))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.08, y: r.maxY - h * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.16, y: r.maxY - h * 0.02), control: CGPoint(x: r.maxX - w * 0.07, y: r.maxY - h * 0.02))
        p.addLine(to: CGPoint(x: r.minX + w * 0.16, y: r.maxY - h * 0.02))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.08, y: r.maxY - h * 0.1), control: CGPoint(x: r.minX + w * 0.07, y: r.maxY - h * 0.02))
        p.closeSubpath()
        return p
    }
}

struct BagHandle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + r.height * 0.34), radius: r.width * 0.2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

/// Étoile fine à 4 branches (étincelles).
struct Star4: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let t = r.width * 0.1
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + t, y: c.y - t))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + t, y: c.y + t))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - t, y: c.y + t))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - t, y: c.y - t))
        p.closeSubpath()
        return p
    }
}

/// Badge « Sans pub » : « AD » barré dans un cercle néon.
struct NoAdsIcon: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "#2A0E1E"))
            Text("AD")
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Circle().strokeBorder(Theme.ghost, lineWidth: size * 0.08)
            Capsule()
                .fill(Theme.ghost)
                .frame(width: size * 0.08, height: size * 0.86)
                .rotationEffect(.degrees(45))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.ghost.opacity(0.6), radius: size * 0.15)
    }
}

/// Coffret cadeau du Pack de départ.
struct GiftIcon: View {
    var size: CGFloat = 44

    var body: some View {
        let pink = LinearGradient(colors: [Color(hex: "#FF7AC3"), Color(hex: "#C2257A")], startPoint: .top, endPoint: .bottom)
        ZStack {
            // Nœud.
            HStack(spacing: 0) {
                Ellipse().stroke(Theme.gold, lineWidth: size * 0.07).frame(width: size * 0.3, height: size * 0.2).rotationEffect(.degrees(-20))
                Ellipse().stroke(Theme.gold, lineWidth: size * 0.07).frame(width: size * 0.3, height: size * 0.2).rotationEffect(.degrees(20))
            }
            .offset(y: -size * 0.36)
            // Boîte et couvercle.
            RoundedRectangle(cornerRadius: size * 0.08).fill(pink)
                .frame(width: size * 0.72, height: size * 0.5)
                .offset(y: size * 0.18)
            RoundedRectangle(cornerRadius: size * 0.06).fill(Color(hex: "#FF9AD2"))
                .frame(width: size * 0.84, height: size * 0.2)
                .offset(y: -size * 0.14)
            // Ruban.
            Rectangle().fill(Theme.gold).frame(width: size * 0.12, height: size * 0.7).offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.ghost.opacity(0.5), radius: size * 0.15)
    }
}
