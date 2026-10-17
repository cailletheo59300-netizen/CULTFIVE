import SwiftUI
import CultFiveCore

/// Écran « Tout voir » des trophées (Profil) : bilan, médailles de maîtrise par domaine, puis vitrine des exploits.
/// Même style que l'étagère du profil (images de médailles et de coupe, grisées tant qu'elles sont à gagner).
struct TrophiesShowcase: View {
    let trophies: TrophiesOverview
    @State private var selected: TrophiesOverview.Exploit?

    private var unlockedExploits: Int { trophies.exploits.filter { $0.unlockedAt != nil }.count }
    private var medals: Int { trophies.mastery.filter { $0.tier != nil }.count }

    /// Exploits gagnés d'abord (les plus récents en tête), puis ceux à gagner.
    private var sortedExploits: [TrophiesOverview.Exploit] {
        let won = trophies.exploits.filter { $0.unlockedAt != nil }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        return won + trophies.exploits.filter { $0.unlockedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            summary
            if !trophies.mastery.isEmpty { mastery }
            exploits
        }
        .sheet(item: $selected) { ExploitDetail(exploit: $0) }
    }

    // MARK: Bilan

    private var summary: some View {
        HStack(spacing: 10) {
            SummaryTile(image: "trophy_cup", value: "\(unlockedExploits)/\(trophies.exploits.count)", label: "Exploits")
            SummaryTile(image: "medal_gold", value: "\(medals)/\(trophies.mastery.count)", label: "Domaines médaillés")
        }
    }

    // MARK: Maîtrise

    private var mastery: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Maîtrise").font(.cfHeadline)
            Text("Une médaille par domaine, selon ta cote : bronze, argent, or puis diamant.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            VStack(spacing: 0) {
                ForEach(Array(trophies.mastery.enumerated()), id: \.element.id) { i, m in
                    if i > 0 { Divider().overlay(Color.hairline).padding(.leading, 66) }
                    MasteryRow(mastery: m)
                }
            }
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: Exploits

    private var exploits: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Exploits").font(.cfHeadline)
            Text("Chaque exploit réussi rapporte un coffre.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(sortedExploits) { exploit in
                    let won = exploit.unlockedAt != nil
                    Button { selected = exploit } label: {
                        VStack(spacing: 4) {
                            Image("trophy_cup").resizable().scaledToFit().frame(width: 56, height: 56)
                                .saturation(won ? 1 : 0).opacity(won ? 1 : 0.4)
                            Text(exploit.name)
                                .font(.system(.caption, design: .rounded).weight(.black))
                                .foregroundStyle(won ? Color.ink : Color.inkSoft)
                                .multilineTextAlignment(.center)
                                .lineLimit(2).minimumScaleFactor(0.8)
                            Text(won ? "Gagné" : "À gagner")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(won ? Color.correct : Color.inkSoft)
                        }
                        .frame(maxWidth: .infinity, minHeight: 124, alignment: .top)
                        .padding(.vertical, 10).padding(.horizontal, 4)
                        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.row)
                    .accessibilityLabel(exploit.name)
                    .accessibilityValue(won ? "gagné" : "à gagner")
                    .accessibilityHint(exploit.description)
                }
            }
        }
    }
}

/// Case du bilan (image, valeur, libellé).
private struct SummaryTile: View {
    let image: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(image).resizable().scaledToFit().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                Text(label).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Ligne d'un domaine : médaille actuelle (grisée si aucune), nom, paliers et prochain objectif.
private struct MasteryRow: View {
    let mastery: TrophiesOverview.Mastery

    private var tierName: String? {
        guard let tier = mastery.tier else { return nil }
        return TrophiesOverview.tiers.first { $0.id == tier }?.name ?? tier
    }

    private var status: String {
        if let tierName { return tierName }
        return mastery.placed ? "Pas encore de médaille" : "Joue pour être classé"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image("medal_\(mastery.tier ?? "bronze")").resizable().scaledToFit().frame(width: 42, height: 42)
                .saturation(mastery.tier != nil ? 1 : 0).opacity(mastery.tier != nil ? 1 : 0.35)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(mastery.name).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    Spacer(minLength: 4)
                    Text(status).font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(mastery.tier != nil ? Color.ink : Color.inkSoft)
                }
                MasteryMedals(mastery: mastery)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

/// Fiche d'un exploit : grande coupe, description, coffre et date d'obtention.
private struct ExploitDetail: View {
    let exploit: TrophiesOverview.Exploit

    var body: some View {
        let won = exploit.unlockedAt != nil
        VStack(spacing: Space.m) {
            Image("trophy_cup").resizable().scaledToFit().frame(width: 96, height: 96)
                .saturation(won ? 1 : 0).opacity(won ? 1 : 0.4)
            Text(exploit.name).font(.cfHeadline).multilineTextAlignment(.center)
            Text(exploit.description).font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            if let chest = exploit.chest {
                HStack(spacing: Space.s) {
                    ChestView(tier: chest, open: won).frame(width: 40)
                    Text(won ? "\(chest.title) gagné" : "Récompense : \(chest.title.lowercased())")
                        .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                }
            }
            if let date = exploit.unlockedAt {
                Text("Gagné le \(date.formatted(.dateTime.day().month(.wide).year()))")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
        .padding(Space.l)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}

/// Médailles de maîtrise d'un domaine (sur les cartes « Ce que tu sais ») et prochain palier.
struct MasteryMedals: View {
    let mastery: TrophiesOverview.Mastery

    private var reached: Int {
        guard let tier = mastery.tier, let i = TrophiesOverview.tiers.firstIndex(where: { $0.id == tier }) else { return 0 }
        return i + 1
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(TrophiesOverview.tiers.enumerated()), id: \.offset) { i, tier in
                TierMedal(tier: tier.id, unlocked: i < reached)
            }
            if mastery.placed, let next = mastery.next {
                let name = TrophiesOverview.tiers.first { $0.id == next.tier }?.name ?? next.tier
                Text("\(name) à \(CoteCULT.format(next.cote))")
                    .font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                    .padding(.leading, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reached == 0 ? "Aucune médaille de maîtrise" : "Médaille \(TrophiesOverview.tiers[reached - 1].name)")
    }
}

/// Petite médaille de palier (bronze, argent, or, diamant).
struct TierMedal: View {
    let tier: String
    let unlocked: Bool

    private var color: Color {
        switch tier {
        case "bronze": return Color(hex: 0xCD7F32)
        case "silver": return Color(hex: 0xADB5BD)
        case "gold": return Color(hex: 0xF2B705)
        default: return Color(hex: 0x66D9E8)
        }
    }

    var body: some View {
        ZStack {
            if tier == "diamond" {
                Image(systemName: "diamond.fill").font(.system(size: 17, weight: .bold))
                    .foregroundStyle(unlocked ? color : Color.hairline)
            } else {
                Circle().fill(unlocked ? color : Color.hairline).frame(width: 18, height: 18)
                Circle().strokeBorder(.white.opacity(unlocked ? 0.5 : 0), lineWidth: 2).frame(width: 18, height: 18)
            }
        }
        .frame(width: 20, height: 20)
    }
}
