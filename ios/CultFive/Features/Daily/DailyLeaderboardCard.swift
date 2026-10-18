import SwiftUI
import CultFiveCore

/// Classement, sur le fond violet du résultat (D-073, D-079) : les vrais joueurs qui ont fait un 5 du jour ces 3
/// derniers jours, chacun avec son dernier. Podium animé pour le top 3, puis « ··· », toi et tes voisins ; confettis
/// si tu es sur le podium ; seul classé : « 1er pour l'instant ».
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

    private var onPodium: Bool { (board?.rank ?? 99) <= 3 && showsBoard }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Classement").labelCaps(.white.opacity(0.7))
                Spacer()
                if onPodium, let rank = board?.rank {
                    Text(rank == 1 ? "🏆 Tu es 1er !" : "🎉 Tu es sur le podium !")
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .foregroundStyle(Color(hex: 0x1E1340))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.sun, in: Capsule())
                }
            }
            if showsBoard {
                LeaderboardBody(entries: entries, style: .onInk)
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
        .overlay {
            if onPodium { Confetti().allowsHitTesting(false).clipShape(RoundedRectangle(cornerRadius: Radius.m)) }
        }
    }
}
