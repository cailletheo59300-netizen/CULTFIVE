import SwiftUI

/// Radar des connaissances : un rayon par domaine, niveau 0–100. Polygone translucide, sommets aux couleurs des domaines.
struct KnowledgeRadar: View {
    struct Axis: Identifiable {
        let domainId: String
        let level: Double
        var id: String { domainId }
    }

    let axes: [Axis]
    var fill: Color = .brand
    var grid: Color = Color.inkSoft.opacity(0.18)
    /// Pictogrammes des domaines au bout des rayons.
    var showSymbols = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = side / 2 - (showSymbols ? 20 : 4)
            ZStack {
                Canvas { context, _ in
                    guard axes.count >= 3 else { return }
                    for ring in [0.25, 0.5, 0.75, 1.0] {
                        context.stroke(polygon(center: center, radius: radius) { _ in ring }, with: .color(grid), lineWidth: 1.2)
                    }
                    for index in axes.indices {
                        var spoke = Path()
                        spoke.move(to: center)
                        spoke.addLine(to: point(index, value: 1, center: center, radius: radius))
                        context.stroke(spoke, with: .color(grid), lineWidth: 1)
                    }
                    let shape = polygon(center: center, radius: radius) { max(axes[$0].level, 4) / 100 }
                    context.fill(shape, with: .color(fill.opacity(0.32)))
                    context.stroke(shape, with: .color(fill), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    for index in axes.indices {
                        let p = point(index, value: max(axes[index].level, 4) / 100, center: center, radius: radius)
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)),
                                     with: .color(DomainPalette.color(axes[index].domainId)))
                    }
                }
                if showSymbols {
                    ForEach(Array(axes.enumerated()), id: \.offset) { index, axis in
                        Image(systemName: DomainPalette.symbol(axis.domainId))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DomainPalette.onColor(axis.domainId))
                            .frame(width: 22, height: 22)
                            .background(DomainPalette.color(axis.domainId), in: Circle())
                            .position(point(index, value: 1, center: center, radius: radius + 13))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Radar des connaissances")
    }

    private func point(_ index: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + Double(index) / Double(max(axes.count, 1)) * 2 * Double.pi
        return CGPoint(x: Double(center.x) + Double(radius) * value * cos(angle),
                       y: Double(center.y) + Double(radius) * value * sin(angle))
    }

    private func polygon(center: CGPoint, radius: CGFloat, value: (Int) -> Double) -> Path {
        var path = Path()
        for index in axes.indices {
            let p = point(index, value: value(index), center: center, radius: radius)
            index == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}
