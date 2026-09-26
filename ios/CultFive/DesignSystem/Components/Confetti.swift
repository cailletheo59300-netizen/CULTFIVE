import SwiftUI

/// Pluie de confettis (sans-faute, trophée, niveau). Une seule salve, puis rien : pas d'animation infinie.
/// Désactivée avec « Réduire les animations ».
struct Confetti: View {
    var colors: [Color] = [.sun, .brand, .blush, .correct, Color(hex: 0x2F6BFF), Color(hex: 0xF76707)]
    var count = 70
    var duration: Double = 2.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var pieces: [Piece] = []

    private struct Piece {
        let x: Double          // position de départ, 0…1
        let delay: Double
        let speed: Double      // écrans par seconde
        let drift: Double
        let spin: Double
        let size: Double
        let color: Int
        let round: Bool
    }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                Canvas { context, size in
                    guard t < duration + 1 else { return }
                    for piece in pieces {
                        let local = t - piece.delay
                        guard local > 0 else { continue }
                        let height = Double(size.height)
                        let fall: Double = local * piece.speed * height
                        let y: Double = fall + 26 * local * local - 20
                        guard y < height + 20 else { continue }
                        let sway: Double = sin(local * 3 + piece.drift) * 18 * piece.drift
                        let x: Double = piece.x * Double(size.width) + sway
                        let fade: Double = max(0, min(1, (duration + 0.6 - local) / 0.6))
                        var c = context
                        c.opacity = fade
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(local * piece.spin))
                        let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / (piece.round ? 1 : 2))
                        let shape = piece.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                        c.fill(shape, with: .color(colors[piece.color % colors.count]))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                start = Date()
                pieces = (0..<count).map { i in
                    Piece(x: .random(in: 0...1), delay: .random(in: 0...0.5), speed: .random(in: 0.35...0.7),
                          drift: .random(in: 0.3...1.6), spin: .random(in: -9...9), size: .random(in: 7...12),
                          color: i, round: .random())
                }
            }
        }
    }
}
