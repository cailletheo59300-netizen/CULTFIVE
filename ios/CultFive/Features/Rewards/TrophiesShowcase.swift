import SwiftUI
import CultFiveCore

/// Vitrine des trophées (Profil) : maîtrise par domaine (Bronze, Argent, Or, Diamant sur l'Elo classé) puis exploits.
/// Chaque trophée a donné un coffre.
struct TrophiesShowcase: View {
    let trophies: TrophiesOverview
    @State private var selected: TrophiesOverview.Exploit?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            mastery
            exploits
        }
        .sheet(item: $selected) { exploit in
            VStack(spacing: Space.m) {
                Medal(unlocked: exploit.unlockedAt != nil, size: 72)
                Text(exploit.name).font(.cfHeadline).multilineTextAlignment(.center)
                Text(exploit.description).font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                if let chest = exploit.chest {
                    HStack(spacing: Space.s) {
                        ChestView(tier: chest, open: exploit.unlockedAt != nil).frame(width: 40)
                        Text(exploit.unlockedAt != nil ? "\(chest.title) gagné" : "Récompense : \(chest.title.lowercased())")
                            .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                    }
                }
            }
            .padding(Space.l)
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Maîtrise

    private var mastery: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Maîtrise").font(.cfHeadline)
                Spacer()
                let count = trophies.mastery.reduce(0) { $0 + tierIndex($1.tier) }
                Text("\(count)/\(trophies.mastery.count * 4)").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
            }
            Text("Bronze à 1 050 d'Elo, Argent à 1 200, Or à 1 350, Diamant à 1 500 (parties classées).")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            VStack(spacing: 0) {
                ForEach(Array(trophies.mastery.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, Space.m) }
                    masteryRow(row)
                }
            }
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
    }

    private func tierIndex(_ tier: String?) -> Int {
        guard let tier, let i = TrophiesOverview.tiers.firstIndex(where: { $0.id == tier }) else { return 0 }
        return i + 1
    }

    private func masteryRow(_ row: TrophiesOverview.Mastery) -> some View {
        let reached = tierIndex(row.tier)
        return HStack(spacing: Space.s) {
            Circle().fill(DomainPalette.color(row.domainId)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(detail(row)).font(.system(.caption, design: .rounded)).foregroundStyle(Color.inkSoft).monospacedDigit()
            }
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                ForEach(Array(TrophiesOverview.tiers.enumerated()), id: \.offset) { i, tier in
                    TierMedal(tier: tier.id, unlocked: i < reached)
                        .accessibilityLabel("\(tier.name) \(i < reached ? "obtenu" : "à obtenir")")
                }
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ row: TrophiesOverview.Mastery) -> String {
        guard row.placed, let cote = row.cote else { return "Termine ton placement (5 parties classées)" }
        guard let next = row.next else { return "Elo \(CoteCULT.format(cote)) · tout est obtenu" }
        let name = TrophiesOverview.tiers.first { $0.id == next.tier }?.name ?? next.tier
        return "Elo \(CoteCULT.format(cote)) → \(name) à \(CoteCULT.format(next.cote))"
    }

    // MARK: Exploits

    private var exploits: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exploits").font(.cfHeadline)
                Spacer()
                Text("\(trophies.exploits.filter { $0.unlockedAt != nil }.count)/\(trophies.exploits.count)")
                    .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(trophies.exploits) { exploit in
                    Button { selected = exploit } label: {
                        VStack(spacing: 6) {
                            Medal(unlocked: exploit.unlockedAt != nil, size: 44)
                            Text(exploit.name)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(exploit.unlockedAt != nil ? Color.ink : Color.inkSoft)
                                .multilineTextAlignment(.center)
                                .lineLimit(2).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .padding(6)
                        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                    }
                    .buttonStyle(.row)
                    .accessibilityLabel(exploit.name)
                    .accessibilityValue(exploit.unlockedAt != nil ? "débloqué" : "à débloquer")
                    .accessibilityHint(exploit.description)
                }
            }
        }
    }
}

/// Médaille d'exploit : soleil doré (débloquée) ou cercle gris verrouillé.
private struct Medal: View {
    let unlocked: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(unlocked ? Color.sun : Color.hairline)
            Circle().strokeBorder(unlocked ? Color(hex: 0xE0A300) : Color.inkSoft.opacity(0.2), lineWidth: size * 0.07)
            Image(systemName: unlocked ? "star.fill" : "lock.fill")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(unlocked ? Color.white : Color.inkSoft.opacity(0.5))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Petite médaille de palier (bronze, argent, or, diamant).
private struct TierMedal: View {
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
