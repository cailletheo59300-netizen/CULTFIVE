import SwiftUI

/// Encart de célébration : trophée débloqué, erreur corrigée, niveau passé.
/// L'icône entre en rebondissant ; les confettis sont gérés par l'écran qui l'affiche.
struct CelebrationCard: View {
    enum Kind { case trophy, corrected, levelUp, rating, quest }

    let kind: Kind
    let title: String
    var detail: String? = nil
    /// Sur un fond coloré (résultat du Daily) : carte translucide, textes blancs.
    var onColor = false

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(kind == .trophy ? Color.inkFixed : .white)
                .frame(width: 50, height: 50)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.45), radius: 8, y: 4)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
                .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -30))
            VStack(alignment: .leading, spacing: 2) {
                Text(caption).labelCaps(onColor ? Color.sun : tint)
                Text(title).font(.cfTitle3).foregroundStyle(onColor ? Color.white : Color.ink)
                if let detail {
                    Text(detail).font(.cfFootnote).foregroundStyle(onColor ? Color.white.opacity(0.7) : Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(onColor ? Color.white.opacity(0.14) : Color.paperRaised,
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .onAppear {
            withAnimation(Motion.bounce.delay(0.2)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .trophy: return "trophy.fill"
        case .corrected: return "checkmark.seal.fill"
        case .levelUp: return "arrow.up.circle.fill"
        case .rating: return "chart.line.uptrend.xyaxis"
        case .quest: return "target"
        }
    }

    private var caption: String {
        switch kind {
        case .trophy: return "Trophée débloqué"
        case .corrected: return "Erreur corrigée"
        case .levelUp: return "Niveau supérieur"
        case .rating: return "Cote CULT"
        case .quest: return "Objectif rempli"
        }
    }

    private var tint: Color {
        switch kind {
        case .trophy: return .sun
        case .corrected: return .correct
        case .levelUp: return .brand
        case .rating: return Color(hex: 0xF76707)
        case .quest: return Color(hex: 0x37B24D)
        }
    }
}
