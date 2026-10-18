import SwiftUI
import CultFiveCore

/// Classement en grande carte nuit (D-073, D-079, D-080) : les vrais joueurs qui ont fait un 5 du jour ces 3 derniers
/// jours, chacun avec son dernier. Podium animé pour le top 3, puis « ··· », toi et tes voisins ; confettis si tu es
/// sur le podium ; seul classé : « 1er pour l'instant ». Pas encore chargé : podium fantôme.
struct DailyLeaderboardCard: View {
    let result: DailyResult
    let board: DailyLeaderboard?
    /// La demande au serveur est terminée (réussie ou non).
    var loaded = true

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

    /// Halo : or pour le 1er, rose sur le podium, violet sinon.
    private var glow: Color {
        guard showsBoard, let rank = board?.rank else { return Color(hex: 0xB57CFF) }
        return rank == 1 ? Color(hex: 0xFFC83D) : rank <= 3 ? Color(hex: 0xFF6FB5) : Color(hex: 0xB57CFF)
    }

    var body: some View {
        LeaderboardHeroCard(glow: glow) {
            if onPodium, let rank = board?.rank {
                Text(rank == 1 ? "🏆 Tu es 1er !" : "🎉 Sur le podium !")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Color(hex: 0x1E1340))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.sun, in: Capsule())
            }
        } content: {
            if showsBoard {
                LeaderboardBody(entries: entries, style: .onInk)
            } else if board == nil && !loaded {
                LeaderboardSkeleton()
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
        .animation(.easeInOut(duration: 0.25), value: board == nil)
        .overlay {
            if onPodium { Confetti().allowsHitTesting(false).clipShape(RoundedRectangle(cornerRadius: 24)) }
        }
    }
}
