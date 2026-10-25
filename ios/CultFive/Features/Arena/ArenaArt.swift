import SwiftUI
import CultFiveCore

// Arène (D-111) : images 3D (blason, couronne, médailles 1 à 3, faites par `scripts/icons`) et petits dessins.

enum ArenaPalette {
    /// Fond nuit de l'Arène (cartes du classement, écrans de duel).
    static let night = LinearGradient(colors: [Color(hex: 0x2A1680), Color(hex: 0x150B45)], startPoint: .top, endPoint: .bottom)
    static let nightTop = Color(hex: 0x2A1680)
    static let gold = Color(hex: 0xFFC933)
    static let me = Color(hex: 0x6A4CFF)
    static let them = Color(hex: 0xF76707)
}

/// Blason de l'Arène (bouclier violet, laurier d'or, trait de cinq, ruban « ARÈNE »).
struct ArenaCrest: View {
    var body: some View {
        Image("arena_crest").resizable().scaledToFit().accessibilityHidden(true)
    }
}

/// Couronne du champion de la semaine.
struct ArenaCrown: View {
    var size: CGFloat = 18

    var body: some View {
        Image("arena_crown").resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityLabel("Champion de la semaine")
    }
}

/// Médaille 3D numérotée (1 à 3) ; au-delà, le rang dans une pastille.
struct ArenaMedal: View {
    let rank: Int
    var size: CGFloat = 40

    var body: some View {
        if (1...3).contains(rank) {
            Image("arena_medal_\(rank)").resizable().scaledToFit().frame(width: size, height: size)
                .accessibilityLabel("\(rank)\(rank == 1 ? "er" : "e")")
        } else {
            Text("\(rank)")
                .font(.system(size: size * 0.4, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(Color.ink)
                .frame(width: size * 0.82, height: size * 0.82)
                .background(Color.paper, in: Circle())
                .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1.5))
                .frame(width: size, height: size)
                .accessibilityLabel("\(rank)e")
        }
    }
}

/// Pseudo, suivi de la couronne s'il est le champion de la semaine passée.
struct ArenaHandle: View {
    let handle: String
    var champion = false
    var font: Font = .system(.callout, design: .rounded).weight(.black)
    var color: Color = .ink

    var body: some View {
        HStack(spacing: 4) {
            Text(handle).font(font).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.75)
            if champion { ArenaCrown(size: 16) }
        }
    }
}

/// Pastille ronde avec l'initiale d'un joueur, à sa couleur (toujours la même pour un même pseudo).
struct ArenaAvatar: View {
    let handle: String
    var size: CGFloat = 44
    var ring: Color? = nil
    var me = false

    private static let tints: [UInt32] = [0x2F6BFF, 0xF0588F, 0x0CA678, 0xF76707, 0x1098AD, 0x845EF7, 0xD6336C, 0xE5383B,
                                          0x5F3DC4, 0x1C7ED6, 0x37B24D]

    private var tint: Color {
        if me { return Color.brand }
        let sum = handle.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hex: Self.tints[sum % Self.tints.count])
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(String(handle.prefix(1)).uppercased())
                    .font(.system(size: size * 0.44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().strokeBorder(ring ?? .clear, lineWidth: max(2, size * 0.06)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Une ligne de récompense : coffres, carte garantie, neurones, pochettes, trophée, cadre, couronne. Toujours lisible :
/// chaque élément a son image et sa légende.
struct ArenaPrizeStrip: View {
    let prize: ArenaPrize
    var onInk = false
    var itemSize: CGFloat = 40

    private struct Item: Identifiable {
        let id: String
        let label: String
        let image: AnyView
    }

    private var items: [Item] {
        var list: [Item] = []
        func chest(_ tier: ChestTier, _ count: Int?, _ name: String) {
            guard let count, count > 0 else { return }
            list.append(Item(id: name, label: count > 1 ? "\(count) coffres \(name)" : "Coffre \(name)",
                             image: AnyView(ChestStack(tier: tier, count: count))))
        }
        chest(.gold, prize.gold, "en or")
        chest(.silver, prize.silver, "d'argent")
        chest(.wood, prize.wood, "en bois")
        if let card = prize.card {
            list.append(Item(id: "card", label: card == "legend" ? "Carte légendaire" : "Carte épique",
                             image: AnyView(RarityCardIcon(legend: card == "legend"))))
        }
        if let packs = prize.packs, packs > 0 {
            list.append(Item(id: "packs", label: packs > 1 ? "\(packs) pochettes" : "1 pochette",
                             image: AnyView(AlbumImage(kind: .pass, name: "ticket_pochette"))))
        }
        if let seeds = prize.seeds, seeds > 0 {
            list.append(Item(id: "seeds", label: "\(seeds) neurones", image: AnyView(AlbumImage(kind: .pass, name: "neurone"))))
        }
        if prize.trophy != nil {
            list.append(Item(id: "trophy", label: prize.trophy == "arena_champion" ? "Trophée Champion" : "Trophée Podium",
                             image: AnyView(Image("trophy_cup").resizable().scaledToFit())))
        }
        if prize.cosmetic != nil {
            list.append(Item(id: "frame", label: "Cadre Champion", image: AnyView(ChampionFrameIcon())))
        }
        if prize.crown == true {
            list.append(Item(id: "crown", label: "Couronne 7 jours", image: AnyView(Image("arena_crown").resizable().scaledToFit())))
        }
        return list
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    item.image.frame(width: itemSize, height: itemSize)
                    Text(item.label)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(onInk ? Color.white.opacity(0.85) : Color.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: itemSize + 22)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.label)
            }
        }
    }
}

/// Coffre 3D avec, s'il y en a plusieurs, le nombre en pastille.
private struct ChestStack: View {
    let tier: ChestTier
    let count: Int

    var body: some View {
        ChestView(tier: tier)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.wrong, in: Capsule())
                        .offset(x: 8, y: -4)
                }
            }
    }
}

/// Petite carte de l'album, aux couleurs de sa rareté (légendaire : or et rayons ; épique : violet).
struct RarityCardIcon: View {
    let legend: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.height * 0.72
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
                    .fill(LinearGradient(colors: legend ? [Color(hex: 0xFFE680), Color(hex: 0xF2B705), Color(hex: 0xC98A00)]
                                                        : [Color(hex: 0xC7B5FF), Color(hex: 0x845EF7), Color(hex: 0x5F3DC4)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: w * 0.1, style: .continuous)
                    .strokeBorder(.white.opacity(0.75), lineWidth: max(1, w * 0.05))
                    .padding(w * 0.08)
                Image(systemName: "star.fill")
                    .font(.system(size: w * 0.42, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
            .frame(width: w, height: proxy.size.height)
            .rotationEffect(.degrees(-8))
            .shadow(color: (legend ? Color(hex: 0xC98A00) : Color(hex: 0x5F3DC4)).opacity(0.4), radius: 4, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Aperçu du cadre « Champion de l'Arène » (or, laurier et couronne), pour l'habillage des cartes.
struct ChampionFrameIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.height * 0.72
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.12, style: .continuous).fill(Color.paperRaised)
                CardFrame(kind: "champion", width: w)
            }
            .frame(width: w, height: proxy.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Compte à rebours de la semaine : « 2 j 4 h », « 3 h 12 min ».
enum ArenaClock {
    static func remaining(until end: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days) j \(hours) h" }
        if hours > 0 { return "\(hours) h \(String(format: "%02d", minutes)) min" }
        return "\(max(minutes, 1)) min"
    }

    /// « 1er », « 2e ».
    static func ordinal(_ rank: Int) -> String { rank == 1 ? "1er" : "\(rank)e" }

    static func places(_ prize: ArenaPrize) -> String {
        guard let from = prize.from else { return "" }
        guard let to = prize.to else { return "\(from)e et +" }
        if from == to { return ordinal(from) }
        return "\(from)e – \(to)e"
    }
}
