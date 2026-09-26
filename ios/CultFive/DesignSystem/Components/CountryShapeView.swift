import SwiftUI
import CultFiveCore

/// Silhouette d'un pays (contours Natural Earth normalisés). Aplat de la couleur du domaine, filet d'encre.
struct CountryShapeView: View {
    let shape: CountryShape
    var color: Color = DomainPalette.color("geography")

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            var path = Path()
            for ring in shape.paths where ring.count >= 3 {
                for (index, point) in ring.enumerated() where point.count >= 2 {
                    let p = CGPoint(x: origin.x + point[0] * side, y: origin.y + point[1] * side)
                    index == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                path.closeSubpath()
            }
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(Color.ink.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        }
        .accessibilityElement()
        .accessibilityLabel("Silhouette d'un pays")
    }
}
