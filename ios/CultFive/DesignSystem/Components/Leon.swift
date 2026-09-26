import SwiftUI

/// Léon, le caméléon de CULT FIVE. Il prend la couleur du domaine : l'adaptation, littéralement.
/// Vectoriel, dessiné en code (aucun asset). Apparitions rares : onboarding, résultats, états vides, trophées, invitations.
struct Leon: View {
    enum Pose { case rest, curious, proud }

    var color: Color = .chloro
    var pose: Pose = .rest

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 120, size.height / 80)
            context.translateBy(x: (size.width - 120 * scale) / 2, y: (size.height - 80 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            if pose == .curious {
                context.translateBy(x: 60, y: 40)
                context.rotate(by: .degrees(-6))
                context.translateBy(x: -60, y: -40)
            }
            let outline = Color.inkFixed
            let line = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)

            // Queue enroulée (derrière le corps)
            var tail = Path()
            tail.move(to: CGPoint(x: 36, y: 47))
            tail.addQuadCurve(to: CGPoint(x: 13, y: 55), control: CGPoint(x: 20, y: 40))
            tail.addArc(center: CGPoint(x: 20, y: 57), radius: 7, startAngle: .degrees(195), endAngle: .degrees(520), clockwise: false)
            context.stroke(tail, with: .color(outline), style: StrokeStyle(lineWidth: 9.4, lineCap: .round, lineJoin: .round))
            context.stroke(tail, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            // Pattes
            for x in [46.0, 68.0] {
                let leg = Path(roundedRect: CGRect(x: x, y: 54, width: 7, height: 13), cornerRadius: 3.5)
                context.fill(leg, with: .color(color))
                context.stroke(leg, with: .color(outline), style: line)
            }

            // Corps + tête
            var body = Path()
            body.move(to: CGPoint(x: 34, y: 44))
            body.addCurve(to: CGPoint(x: 76, y: 26), control1: CGPoint(x: 34, y: 28), control2: CGPoint(x: 58, y: 22))
            body.addQuadCurve(to: CGPoint(x: 107, y: 45), control: CGPoint(x: 101, y: 26))
            body.addQuadCurve(to: CGPoint(x: 80, y: 58), control: CGPoint(x: 101, y: 58))
            body.addCurve(to: CGPoint(x: 34, y: 44), control1: CGPoint(x: 62, y: 62), control2: CGPoint(x: 36, y: 60))
            body.closeSubpath()
            context.fill(body, with: .color(color))
            context.stroke(body, with: .color(outline), style: line)

            // Casque
            var crest = Path()
            crest.move(to: CGPoint(x: 74, y: 27))
            crest.addQuadCurve(to: CGPoint(x: 92, y: 25), control: CGPoint(x: 80, y: 13))
            context.stroke(crest, with: .color(outline), style: line)

            // Motif dorsal discret
            for (x, y) in [(48.0, 36.0), (58.0, 32.0), (68.0, 31.0)] {
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)), with: .color(outline.opacity(0.18)))
            }

            // Œil tourelle
            let eyeCenter = CGPoint(x: 91, y: 38)
            let eye = Path(ellipseIn: CGRect(x: eyeCenter.x - 8.5, y: eyeCenter.y - 8.5, width: 17, height: 17))
            context.fill(eye, with: .color(.paperFixed))
            context.stroke(eye, with: .color(outline), style: line)
            switch pose {
            case .proud:
                var closed = Path()
                closed.move(to: CGPoint(x: 85.5, y: 39))
                closed.addQuadCurve(to: CGPoint(x: 96.5, y: 39), control: CGPoint(x: 91, y: 33))
                context.stroke(closed, with: .color(outline), style: line)
                var smile = Path()
                smile.move(to: CGPoint(x: 94, y: 51))
                smile.addQuadCurve(to: CGPoint(x: 104, y: 47), control: CGPoint(x: 100, y: 52))
                context.stroke(smile, with: .color(outline), style: line)
            case .curious:
                context.fill(Path(ellipseIn: CGRect(x: 85.5, y: 32, width: 7, height: 7)), with: .color(outline))
            case .rest:
                context.fill(Path(ellipseIn: CGRect(x: 88.5, y: 35, width: 7, height: 7)), with: .color(outline))
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Léon, le caméléon")
    }
}

#Preview {
    HStack(spacing: 24) {
        Leon(color: .chloro, pose: .rest)
        Leon(color: DomainPalette.color("geography"), pose: .curious)
        Leon(color: DomainPalette.color("history"), pose: .proud)
    }
    .frame(height: 90)
    .padding()
    .background(Color.paper)
}
