import SwiftUI
import CultFiveCore

// Classements (D-073, D-074) : un vrai podium pour le top 3, puis des lignes. Partagé entre la fin du 5 du jour
// (fond violet) et l'écran Amis (fond clair).

/// Une place de classement.
struct RankEntry: Identifiable {
    let id: String
    var rank: Int?
    let handle: String
    /// nil : pas encore joué.
    let score: Int?
    let totalMs: Int?
    let streak: Int?
    let me: Bool
    /// Bonnes et mauvaises réponses, dans l'ordre (le trait de cinq) ; nil : non affiché.
    var answers: [Bool]? = nil
}

/// Fond du classement : violet (fin du 5 du jour) ou clair (Amis).
enum RankStyle {
    case onInk, onPaper

    var text: Color { self == .onInk ? .white : .ink }
    var soft: Color { self == .onInk ? .white.opacity(0.65) : .inkSoft }
    var rowFill: Color { self == .onInk ? .white.opacity(0.08) : .paperRaised }
}

enum Medal {
    static func colors(_ rank: Int) -> [Color] {
        switch rank {
        case 1: return [Color(hex: 0xFFE066), Color(hex: 0xF2B705)]
        case 2: return [Color(hex: 0xF1F3F5), Color(hex: 0xADB5BD)]
        default: return [Color(hex: 0xF4C08E), Color(hex: 0xCD7F32)]
        }
    }
}

/// Podium : 2e à gauche, 1er au centre (plus haut, couronné), 3e à droite.
struct PodiumView: View {
    let entries: [RankEntry]
    var style: RankStyle = .onInk
    /// Une place touchée (profil d'un ami) ; nil : podium non touchable.
    var onSelect: ((RankEntry) -> Void)? = nil

    private var ordered: [RankEntry] {
        let byRank = Dictionary(entries.compactMap { e in e.rank.map { ($0, e) } }, uniquingKeysWith: { a, _ in a })
        return [2, 1, 3].compactMap { byRank[$0] }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(ordered) { entry in
                if let onSelect, !entry.me {
                    Button { onSelect(entry) } label: {
                        PodiumColumn(entry: entry, style: style).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.row)
                    .accessibilityHint("Ouvre son profil")
                } else {
                    PodiumColumn(entry: entry, style: style).frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct PodiumColumn: View {
    let entry: RankEntry
    let style: RankStyle

    private var rank: Int { entry.rank ?? 3 }
    private var height: CGFloat { rank == 1 ? 74 : rank == 2 ? 54 : 40 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(LinearGradient(colors: Medal.colors(rank), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: rank == 1 ? 58 : 48, height: rank == 1 ? 58 : 48)
                    .overlay(Circle().strokeBorder(entry.me ? Color.sun : .white.opacity(0.7), lineWidth: entry.me ? 3 : 2))
                    .overlay(
                        Text(initial)
                            .font(.system(rank == 1 ? .title2 : .title3, design: .rounded).weight(.black))
                            .foregroundStyle(Color(hex: 0x1E1340).opacity(0.8))
                    )
                    .shadow(color: Medal.colors(rank)[1].opacity(0.5), radius: 8, y: 3)
                if rank == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(LinearGradient(colors: Medal.colors(1), startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .offset(y: -18)
                }
            }
            .padding(.top, rank == 1 ? 14 : 0)
            Text(entry.me ? "Toi" : entry.handle)
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(entry.me ? Color.sun : style.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let score = entry.score {
                Text("\(score)/5").font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(style.text)
            }
            if let answers = entry.answers {
                TallyMark(results: answers, onInk: style == .onInk).frame(width: 34)
            } else if let totalMs = entry.totalMs {
                Text(DurationFormat.clock(milliseconds: totalMs))
                    .font(.system(.caption2, design: .rounded).weight(.bold)).monospacedDigit()
                    .foregroundStyle(style.soft)
            }
            // La marche du podium, aux couleurs de la médaille.
            UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: Medal.colors(rank).map { $0.opacity(style == .onInk ? 0.9 : 0.75) },
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: height)
                .overlay(alignment: .top) {
                    Text("\(rank)")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .padding(.top, 6)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var initial: String { String((entry.me ? "Toi" : entry.handle).prefix(1)).uppercased() }

    private var accessibilityText: String {
        var parts = ["\(rank)e", entry.me ? "toi" : entry.handle]
        if let score = entry.score { parts.append("\(score) sur 5") }
        if let totalMs = entry.totalMs { parts.append(DurationFormat.clock(milliseconds: totalMs)) }
        return parts.joined(separator: ", ")
    }
}

/// Ligne de classement (hors podium) : rang, pseudo et série, score, temps ou trait de cinq ; « pas encore joué » grisé.
struct RankRow: View {
    let entry: RankEntry
    var style: RankStyle = .onInk
    var showsChevron = false

    var body: some View {
        let played = entry.score != nil
        HStack(spacing: 10) {
            Text(entry.rank.map(String.init) ?? "–")
                .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.soft)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.me ? "Toi" : entry.handle)
                    .font(.system(.callout, design: .rounded).weight(.black))
                    .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
                    .lineLimit(1)
                if let streak = entry.streak, streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color(hex: 0xE8452C))
                }
            }
            Spacer(minLength: 4)
            if let score = entry.score {
                if let answers = entry.answers {
                    TallyMark(results: answers, onInk: style == .onInk && !entry.me).frame(width: 34)
                } else if let totalMs = entry.totalMs {
                    Text(DurationFormat.clock(milliseconds: totalMs))
                        .font(.system(.caption, design: .rounded).weight(.bold)).monospacedDigit()
                        .foregroundStyle(entry.me ? Color(hex: 0x1E1340).opacity(0.7) : style.soft)
                }
                Text("\(score)/5")
                    .font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
            } else {
                Text("pas encore joué").font(.cfFootnote).foregroundStyle(style.soft)
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(style.soft.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
        .background(entry.me ? Color.sun : style.rowFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(played ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }
}

/// « ··· » entre deux rangs non consécutifs.
struct RankGap: View {
    var style: RankStyle = .onInk

    var body: some View {
        Text("···").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(style.soft.opacity(0.7))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
