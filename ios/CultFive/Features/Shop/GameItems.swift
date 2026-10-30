import SwiftUI
import CultFiveCore

/// Les objets qu'on pose avant une partie (D-119). Le serveur les retire du stock et applique leur effet.
enum GameItem: String, CaseIterable, Identifiable {
    case energy, shield, bet, lifeline, hourglass

    var id: String { rawValue }

    var name: String {
        switch self {
        case .energy: return "Boisson énergisante"
        case .shield: return "Bouclier d'Elo"
        case .bet: return "Pari ×3"
        case .lifeline: return "Bouclier de survie"
        case .hourglass: return "Sablier"
        }
    }

    /// L'effet, en quelques mots.
    var effect: String {
        switch self {
        case .energy: return "Elo gagné ×2"
        case .shield: return "Aucune perte d'Elo"
        case .bet: return "Dès 8/10 : Elo ×3"
        case .lifeline: return "1 erreur pardonnée"
        case .hourglass: return "+10 s par question"
        }
    }

    /// Le revers, s'il y en a un (Pari ×3), affiché en rouge sous l'effet.
    var risk: String? { self == .bet ? "Sinon : perte ×2" : nil }

    /// L'effet en entier (aperçu et boutique).
    var detail: String {
        switch self {
        case .energy: return "Tout l'Elo que tu gagnes dans la partie compte double. Les pertes restent normales."
        case .shield: return "Tu ne perds pas d'Elo sur la partie, même si elle se passe mal."
        case .bet: return "8 bonnes réponses sur 10 ou plus : ton Elo gagné compte triple. Sinon : aucun gain, et une perte doublée. Se joue seul."
        case .lifeline: return "Ta première mauvaise réponse en Survie ne compte pas : tu continues."
        case .hourglass: return "10 secondes de plus pour chaque question de ta Survie."
        }
    }

    var image: String { "item_\(rawValue)" }

    var tint: Color {
        switch self {
        case .energy: return Color(hex: 0x6A2CFF)
        case .shield: return Color(hex: 0x1C7ED6)
        case .bet: return Color(hex: 0xE03131)
        case .lifeline: return Color(hex: 0xFF6B2C)
        case .hourglass: return Color(hex: 0xC98A2B)
        }
    }

    /// Objets des parties classées (Elo) et de la Survie.
    static let ranked: [GameItem] = [.energy, .shield, .bet]
    static let survival: [GameItem] = [.lifeline, .hourglass]

    /// Le Pari se joue seul : le choisir retire les autres, et inversement.
    static func toggle(_ item: GameItem, in selection: inout Set<GameItem>) {
        if selection.contains(item) {
            selection.remove(item)
        } else {
            if item == .bet { selection.removeAll() } else { selection.remove(.bet) }
            selection.insert(item)
        }
    }
}

/// « Tes objets » avant la partie : chaque objet dans un rond, toujours montré. Avec du stock, on le touche pour
/// l'activer ; sans stock, il reste visible, grisé, et « Obtenir » ouvre la boutique.
struct ItemsStrip: View {
    let items: [GameItem]
    @Binding var selection: Set<GameItem>
    /// Couleur du texte sur le fond de l'écran.
    var onColor: Color = .white

    @Environment(AppModel.self) private var app
    /// La boutique s'ouvre ici même (la partie est déjà en plein écran).
    @State private var showShop = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Tes objets")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(onColor)
                Spacer()
                Button {
                    Haptics.selection()
                    app.track("shop_view", ["from": "pregame"])
                    showShop = true
                } label: {
                    Label("Obtenir", systemImage: "plus.circle.fill")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(onColor)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(items) { item in
                    ItemCell(item: item, count: app.boostStock[item.rawValue] ?? 0, on: selection.contains(item),
                             onColor: onColor) {
                        if (app.boostStock[item.rawValue] ?? 0) > 0 {
                            Haptics.selection()
                            withAnimation(Motion.bounce) { GameItem.toggle(item, in: &selection) }
                        } else {
                            Haptics.selection()
                            app.track("shop_view", ["from": "pregame_\(item.rawValue)"])
                            showShop = true
                        }
                    }
                }
            }
        }
        .task { await app.refreshBoutique() }
        .fullScreenCover(isPresented: $showShop, onDismiss: { Task { await app.refreshBoutique() } }) { ShopView(focus: .packs) }
    }
}

/// Un objet dans son rond : l'icône 3D, le nombre possédé, le nom, l'effet, et « Utiliser » ou « Activé ».
private struct ItemCell: View {
    let item: GameItem
    let count: Int
    let on: Bool
    let onColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(on ? AnyShapeStyle(Color.sun) : AnyShapeStyle(Color.white.opacity(count > 0 ? 0.95 : 0.35)))
                        .overlay(Circle().strokeBorder(on ? Color.white : item.tint.opacity(0.35), lineWidth: on ? 3 : 1.5))
                        .shadow(color: on ? Color.sun.opacity(0.7) : .black.opacity(0.12), radius: on ? 12 : 5, y: 3)
                    Image(item.image).resizable().scaledToFit()
                        .padding(9)
                        .saturation(count > 0 ? 1 : 0.2)
                        .opacity(count > 0 ? 1 : 0.6)
                    Text("×\(count)")
                        .font(.system(size: 12, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(count > 0 ? Color.white : Color.inkFixed)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(count > 0 ? item.tint : Color.white.opacity(0.8), in: Capsule())
                        .offset(x: 4, y: -2)
                }
                .frame(width: 72, height: 72)
                .scaleEffect(on ? 1.06 : 1)
                Text(item.name)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(onColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.85)
                Text(item.effect)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(item.risk == nil ? onColor.opacity(0.85) : Color(hex: 0x2F9E44))
                    .padding(.horizontal, item.risk == nil ? 0 : 5)
                    .background(item.risk == nil ? Color.clear : Color.white.opacity(0.9), in: Capsule())
                    .multilineTextAlignment(.center)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let risk = item.risk {
                    Text(risk)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0xE03131))
                        .padding(.horizontal, 5)
                        .background(Color.white.opacity(0.9), in: Capsule())
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Text(on ? "Activé ✓" : count > 0 ? "Utiliser" : "Obtenir")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(on ? Color.inkFixed : count > 0 ? item.tint : onColor.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(on ? Color.sun : count > 0 ? Color.white : Color.white.opacity(0.18), in: Capsule())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.row)
        .accessibilityLabel("\(item.name), \(item.effect), \(count) en stock\(on ? ", activé" : "")")
    }
}

/// Bilan d'une partie classée : les objets utilisés et ce qu'ils ont changé à l'Elo.
struct BoostsOutcome: View {
    let boosts: GameBoosts

    private var items: [GameItem] { boosts.items.compactMap(GameItem.init(rawValue:)) }

    private var line: String {
        if boosts.items.contains(GameItem.bet.rawValue) {
            if boosts.betWon == true { return "Pari gagné ! Ton Elo gagné compte triple." }
            return "Pari perdu : pas de gain cette fois."
        }
        guard let extra = boosts.eloExtra else { return "Objets utilisés sur cette partie." }
        if extra > 0 { return "+\(extra) Elo en plus grâce à tes objets." }
        if extra < 0 { return "\(extra) Elo de plus perdus." }
        return boosts.items.contains(GameItem.shield.rawValue) ? "Bouclier : aucune perte d'Elo." : "Objets utilisés sur cette partie."
    }

    var body: some View {
        HStack(spacing: Space.s) {
            HStack(spacing: -10) {
                ForEach(items) { item in
                    Image(item.image).resizable().scaledToFit().frame(width: 36, height: 36)
                }
            }
            Text(line)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.sun.opacity(0.18), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
