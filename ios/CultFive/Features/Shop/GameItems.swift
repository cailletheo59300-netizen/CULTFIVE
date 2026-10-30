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
        case .energy: return "Elo ×2 · 30 min"
        case .shield: return "0 perte · 3 parties"
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
        case .energy: return "Pendant 30 minutes, tout l'Elo que tu gagnes en partie classée compte double. Les pertes restent normales."
        case .shield: return "Tes 3 prochaines parties classées ne te font perdre aucun Elo, même si elles se passent mal."
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
                             onColor: onColor, running: running(item)) {
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

extension ItemsStrip {
    /// Ce qui court déjà (D-122) : « 24 min » pour la Boisson, « 2 parties » pour le Bouclier.
    func running(_ item: GameItem) -> String? {
        switch item {
        case .energy:
            guard let until = app.energyUntil else { return nil }
            return "\(max(1, Int(until.timeIntervalSinceNow / 60))) min"
        case .shield:
            let games = app.shieldGames
            return games > 0 ? "\(games) partie\(games > 1 ? "s" : "")" : nil
        default:
            return nil
        }
    }
}

/// Un objet dans son rond : l'icône 3D, le nombre possédé, le nom, l'effet, et « Utiliser » ou « Activé ».
/// Une Boisson ou un Bouclier déjà en cours le dit (« Actif · 24 min ») ; en poser un autre ajoute du temps.
private struct ItemCell: View {
    let item: GameItem
    let count: Int
    let on: Bool
    let onColor: Color
    var running: String? = nil
    let action: () -> Void

    /// Libellé du bouton sous l'objet.
    private var label: String {
        if on { return running == nil ? "Activé ✓" : (item == .energy ? "+30 min ✓" : "+3 parties ✓") }
        if let running { return "Actif · \(running)" }
        return count > 0 ? "Utiliser" : "Obtenir"
    }

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
                Text(label)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(on ? Color.inkFixed : running != nil ? .white : count > 0 ? item.tint : onColor.opacity(0.8))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(on ? Color.sun : running != nil ? Color.correct : count > 0 ? Color.white : Color.white.opacity(0.18),
                                in: Capsule())
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

/// Sur l'accueil, tant qu'une Boisson ou un Bouclier court : « ⚡ Elo ×2 · 24 min », « 🛡️ Bouclier · 2 parties ».
struct ActiveBoostsBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let energy = app.energyUntil
            let shield = app.shieldGames
            if energy != nil || shield > 0 {
                HStack(spacing: 8) {
                    if let energy {
                        chip(.energy, "Elo ×2 · \(max(1, Int(energy.timeIntervalSinceNow / 60))) min")
                    }
                    if shield > 0 {
                        chip(.shield, "Bouclier · \(shield) partie\(shield > 1 ? "s" : "")")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chip(_ item: GameItem, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(item.image).resizable().scaledToFit().frame(width: 24, height: 24)
            Text(text)
                .font(.system(.footnote, design: .rounded).weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.leading, 5).padding(.trailing, 11).padding(.vertical, 4)
        .background(item.tint, in: Capsule())
        .shadow(color: item.tint.opacity(0.35), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }
}
