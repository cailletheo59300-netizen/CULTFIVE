import SwiftUI
import CultFiveCore

/// Classement du 5 du jour, sur le fond violet du résultat (D-073). Dès 5 joueurs : podium, toi et tes voisins.
/// Avant : ta ligne et la part des parties de la semaine que tu bats (« 1er pour l'instant » si tu ouvres le bal).
/// Score, temps et série sont dans ta ligne : plus de cases séparées.
struct DailyLeaderboardCard: View {
    let result: DailyResult
    let board: DailyLeaderboard?

    private let white = Color.white

    private var showsBoard: Bool {
        guard let board else { return false }
        return board.participants >= DailyLeaderboard.minimumPlayers && board.rank != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Classement du jour").labelCaps(white.opacity(0.7))
                Spacer()
                if showsBoard, let board {
                    Text("\(board.participants) joueurs")
                        .font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(white.opacity(0.7))
                }
            }
            if showsBoard, let board {
                rows(board)
            } else {
                if let headline {
                    Text(headline)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LeaderRow(rank: board?.rank, handle: "Toi", score: result.score, totalMs: result.totalMs,
                          streak: result.streak, me: true)
            }
        }
        .padding(14)
        .background(white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }

    /// Avant 5 joueurs : jamais « pas assez de joueurs », toujours une comparaison qui a du sens.
    private var headline: String? {
        guard let board else { return nil }
        if board.rank == 1 { return "🏆 1er pour l'instant" }
        if let pct = board.weekBeatenPct { return "Mieux que \(pct) % des joueurs cette semaine" }
        return nil
    }

    /// Lignes affichées, avec « ··· » entre deux rangs non consécutifs.
    private func rows(_ board: DailyLeaderboard) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(board.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0, row.rank - board.rows[index - 1].rank > 1 {
                    Text("···").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                LeaderRow(rank: row.rank, handle: row.me ? "Toi" : row.handle, score: row.score, totalMs: row.totalMs,
                          streak: row.me ? result.streak : nil, me: row.me)
            }
        }
    }
}

/// Une ligne : rang (médaille sur le podium), pseudo, score et temps ; ta ligne est surlignée et porte ta série.
private struct LeaderRow: View {
    let rank: Int?
    let handle: String
    let score: Int
    let totalMs: Int?
    let streak: Int?
    let me: Bool

    private static let medals: [Int: Color] = [1: Color(hex: 0xF2B705), 2: Color(hex: 0xC9CED6), 3: Color(hex: 0xD08A4E)]

    var body: some View {
        HStack(spacing: 10) {
            rankBadge
            Text(handle)
                .font(.system(.callout, design: .rounded).weight(me ? .black : .bold))
                .foregroundStyle(me ? Color(hex: 0x1E1340) : .white)
                .lineLimit(1)
            if me, let streak, streak > 0 {
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color(hex: 0xE8452C))
                    .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 4)
            if let totalMs {
                Text(DurationFormat.clock(milliseconds: totalMs))
                    .font(.system(.caption, design: .rounded).weight(.bold)).monospacedDigit()
                    .foregroundStyle(me ? Color(hex: 0x1E1340).opacity(0.7) : .white.opacity(0.6))
            }
            Text("\(score)/5")
                .font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(me ? Color(hex: 0x1E1340) : .white)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
        .background(me ? Color.sun : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var rankBadge: some View {
        if let rank {
            Text("\(rank)")
                .font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(Self.medals[rank] != nil ? Color(hex: 0x1E1340) : (me ? Color(hex: 0x1E1340) : .white))
                .frame(width: 26, height: 26)
                .background(Self.medals[rank] ?? (me ? Color.white.opacity(0.5) : Color.white.opacity(0.14)), in: Circle())
        }
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let rank { parts.append("\(rank)e") }
        parts.append(handle)
        parts.append("\(score) sur 5")
        if let totalMs { parts.append(DurationFormat.clock(milliseconds: totalMs)) }
        if me, let streak, streak > 0 { parts.append("série de \(streak) jours") }
        return parts.joined(separator: ", ")
    }
}
