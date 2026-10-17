import SwiftUI
import CultFiveCore

/// Écran « Tout voir » des trophées (Profil) : bilan, puis tous les exploits.
/// Même style que l'étagère du profil (coupes grisées tant qu'elles sont à gagner).
struct TrophiesShowcase: View {
    let trophies: TrophiesOverview
    @State private var selected: TrophiesOverview.Exploit?

    private var unlockedExploits: Int { trophies.exploits.filter { $0.unlockedAt != nil }.count }

    /// Exploits gagnés d'abord (les plus récents en tête), puis ceux à gagner.
    private var sortedExploits: [TrophiesOverview.Exploit] {
        let won = trophies.exploits.filter { $0.unlockedAt != nil }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        return won + trophies.exploits.filter { $0.unlockedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            summary
            exploits
        }
        .sheet(item: $selected) { ExploitDetail(exploit: $0) }
    }

    // MARK: Bilan

    private var summary: some View {
        let total = max(trophies.exploits.count, 1)
        return HStack(spacing: 12) {
            Image("trophy_cup").resizable().scaledToFit().frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(unlockedExploits) exploit\(unlockedExploits > 1 ? "s" : "") sur \(trophies.exploits.count)")
                    .font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                ProgressView(value: Double(unlockedExploits), total: Double(total))
                    .tint(Color.sun)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
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
