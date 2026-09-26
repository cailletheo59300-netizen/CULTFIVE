import SwiftUI

/// Le « trait de cinq » : quatre traits verticaux barrés d'une diagonale. Élément signature de CULT FIVE.
/// Chaque trait porte l'état d'une question du 5 du jour.
enum TallyStroke: Equatable {
    case empty      // pas encore joué
    case current    // question en cours
    case correct
    case wrong
    case ready      // Daily disponible : diagonale jaune soleil
}

struct TallyMark: View {
    var strokes: [TallyStroke]
    /// Palette : sur fond clair (violet de marque) ou sur fond coloré (blanc / soleil).
    var onInk: Bool = false
    var lineWidth: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    init(strokes: [TallyStroke], onInk: Bool = false, lineWidth: CGFloat? = nil) {
        var padded = Array(strokes.prefix(5))
        while padded.count < 5 { padded.append(.empty) }
        self.strokes = padded
        self.onInk = onInk
        self.lineWidth = lineWidth
    }

    /// À partir des résultats du Daily (vrai = juste). Les positions manquantes sont vides.
    init(results: [Bool], current: Int? = nil, onInk: Bool = false, lineWidth: CGFloat? = nil) {
        var strokes = results.map { $0 ? TallyStroke.correct : .wrong }
        if let current, current == strokes.count, current < 5 { strokes.append(.current) }
        self.init(strokes: strokes, onInk: onInk, lineWidth: lineWidth)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = lineWidth ?? max(proxy.size.width * 0.1, 3)
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    TallyStrokeShape(index: index)
                        // Raté : un trait « manqué », plus court et estompé (forme + couleur, jamais la couleur seule).
                        .trim(from: strokes[index] == .wrong ? 0.3 : 0, to: strokes[index] == .wrong ? 0.7 : 1)
                        .stroke(color(for: strokes[index], index: index),
                                style: StrokeStyle(lineWidth: width, lineCap: .round))
                        .opacity(strokes[index] == .current ? (pulse ? 1 : 0.35) : 1)
                }
            }
        }
        .aspectRatio(1.1, contentMode: .fit)
        .onAppear {
            guard strokes.contains(.current), !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func color(for stroke: TallyStroke, index: Int) -> Color {
        let base: Color = onInk ? .paperFixed : .brand
        switch stroke {
        case .empty: return onInk ? Color.paperFixed.opacity(0.2) : Color.brand.opacity(0.14)
        case .current: return base
        case .correct: return index == 4 ? (onInk ? .sun : Color.correct) : base
        case .wrong: return onInk ? Color.paperFixed.opacity(0.35) : Color.wrong.opacity(0.55)
        case .ready: return onInk ? .sun : Color(hex: 0xFFB020)
        }
    }


    private var accessibilityText: String {
        let correct = strokes.filter { $0 == .correct }.count
        let answered = strokes.filter { $0 == .correct || $0 == .wrong }.count
        if strokes.contains(.ready) { return "Le 5 du jour est prêt" }
        if answered == 0 { return "5 du jour, pas encore commencé" }
        return "\(correct) bonne\(correct > 1 ? "s" : "") réponse\(correct > 1 ? "s" : "") sur \(answered)"
    }
}

/// Un trait. Légère inclinaison des verticales : un geste de main, pas une grille.
struct TallyStrokeShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        if index < 4 {
            let x = w * (0.16 + CGFloat(index) * 0.21)
            path.move(to: CGPoint(x: x - w * 0.015, y: h * 0.94))
            path.addLine(to: CGPoint(x: x + w * 0.02, y: h * 0.06))
        } else {
            path.move(to: CGPoint(x: w * 0.02, y: h * 0.74))
            path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.28))
        }
        return path
    }
}

#Preview {
    VStack(spacing: 32) {
        TallyMark(strokes: [.empty, .empty, .empty, .empty, .ready]).frame(width: 120)
        TallyMark(results: [true, false, true], current: 3).frame(width: 120)
        TallyMark(results: [true, true, false, true, true], onInk: true)
            .frame(width: 160).padding().background(Color.inkFixed)
    }
    .padding()
    .background(Color.paper)
}
