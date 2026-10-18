import SwiftUI
import CultFiveCore

/// Classement, sur le fond violet du résultat (D-073) : chaque joueur avec son dernier 5 du jour, quelle que soit sa
/// date (tant qu'il y a peu de joueurs). Podium pour le top 3, puis « ··· », toi et tes voisins ; seul classé :
/// « 1er pour l'instant ». Score, temps et série sont dans ta ligne : plus de cases séparées.
struct DailyLeaderboardCard: View {
    let result: DailyResult
    let board: DailyLeaderboard?

    private var entries: [RankEntry] {
        (board?.rows ?? []).map { row in
            RankEntry(id: "\(row.rank)", rank: row.rank, handle: row.handle, score: row.score, totalMs: row.totalMs,
                      streak: row.me ? result.streak : nil, me: row.me)
        }
    }

    private var showsBoard: Bool {
        guard let board else { return false }
        return board.participants >= DailyLeaderboard.minimumPlayers && board.rank != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classement").labelCaps(.white.opacity(0.7))
            if showsBoard {
                let podium = entries.filter { ($0.rank ?? 99) <= 3 }
                let others = entries.filter { ($0.rank ?? 0) > 3 }
                PodiumView(entries: podium, style: .onInk)
                if !others.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { index, entry in
                            let previous = index == 0 ? 3 : (others[index - 1].rank ?? 0)
                            if (entry.rank ?? 0) - previous > 1 { RankGap(style: .onInk) }
                            RankRow(entry: entry, style: .onInk)
                        }
                    }
                }
            } else {
                if board?.rank == 1 {
                    Text("🏆 1er pour l'instant")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                }
                RankRow(entry: RankEntry(id: "moi", rank: board?.rank, handle: "Toi", score: result.score,
                                         totalMs: result.totalMs, streak: result.streak, me: true), style: .onInk)
            }
        }
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}
