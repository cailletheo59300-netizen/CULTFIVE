import SwiftUI
import CultFiveCore

// Classements (D-073, D-074, D-079) : un podium animé pour le top 3 (fin du 5 du jour, fiche d'un domaine), des
// lignes avec médailles en relief (Amis, et sous le podium).

/// Une place de classement.
struct RankEntry: Identifiable {
    let id: String
    var rank: Int?
    let handle: String
    /// 5 du jour : score sur 5 (nil : pas encore joué).
    let score: Int?
    let totalMs: Int?
    let streak: Int?
    let me: Bool
    /// Bonnes et mauvaises réponses, dans l'ordre (le trait de cinq) ; nil : non affiché.
    var answers: [Bool]? = nil
    /// Classement d'un domaine : Elo (à la place du score).
    var elo: Int? = nil
    /// 5 du jour (D-091) : partie d'hier (1) ou d'avant-hier (2), affichée en petit.
    var ago: Int? = nil
    /// Arène (D-111) : points de la semaine (à la place du score).
    var points: Int? = nil
    /// Arène : champion de la semaine passée (couronne à côté du pseudo).
    var champion = false
    /// Unité des points (« pts », « victoires »).
    var unit = "pts"
    /// Amis (D-112) : petite étiquette à côté du pseudo (« t'a défié ! », « 3–2 pour toi »).
    var tag: String? = nil
    var tagColor: Color = .brand
    /// Étiquette pleine (une action attend) ou douce.
    var tagFilled = false
    /// Avatar du joueur (D-113), affiché à côté de la médaille si `showsAvatar`.
    var avatar: JSONValue? = nil
    var showsAvatar = false

    var played: Bool { score != nil || elo != nil || points != nil }
    var isPast: Bool { (ago ?? 0) > 0 }
}

/// Fond du classement : violet (fin du 5 du jour) ou clair (Amis, fiche d'un domaine).
enum RankStyle {
    case onInk, onPaper

    var text: Color { self == .onInk ? .white : .ink }
    var soft: Color { self == .onInk ? .white.opacity(0.65) : .inkSoft }
    var rowFill: Color { self == .onInk ? .white.opacity(0.08) : .paperRaised }
}

enum Medal {
    static func colors(_ rank: Int) -> [Color] {
        switch rank {
        case 1: return [Color(hex: 0xFFE680), Color(hex: 0xF2B705), Color(hex: 0xC98A00)]
        case 2: return [Color(hex: 0xFFFFFF), Color(hex: 0xC4CAD0), Color(hex: 0x8D959E)]
        default: return [Color(hex: 0xF8CFA0), Color(hex: 0xD08A4E), Color(hex: 0x9C5A24)]
        }
    }
}

/// Médaille en relief (1, 2, 3) : disque dégradé, liseré clair, petit ruban, numéro gravé. Au-delà : numéro sobre.
struct MedalBadge: View {
    let rank: Int?
    var size: CGFloat = 30
    var style: RankStyle = .onPaper
    var me = false

    var body: some View {
        if let rank, rank <= 3 {
            ZStack(alignment: .top) {
                // Ruban derrière la médaille.
                HStack(spacing: size * 0.08) {
                    Rectangle().fill(rank == 1 ? Color(hex: 0xE8452C) : rank == 2 ? Color(hex: 0x2F6BFF) : Color(hex: 0x12B76A))
                        .frame(width: size * 0.22, height: size * 0.5)
                        .rotationEffect(.degrees(18), anchor: .top)
                    Rectangle().fill(rank == 1 ? Color(hex: 0xFF8A3D) : rank == 2 ? Color(hex: 0x6A9BFF) : Color(hex: 0x3DDC97))
                        .frame(width: size * 0.22, height: size * 0.5)
                        .rotationEffect(.degrees(-18), anchor: .top)
                }
                .offset(y: -size * 0.12)
                Circle()
                    .fill(LinearGradient(colors: Medal.colors(rank), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().inset(by: size * 0.1).strokeBorder(.white.opacity(0.55), lineWidth: max(1, size * 0.05)))
                    .overlay(
                        Text("\(rank)")
                            .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                            .foregroundStyle(Medal.colors(rank)[2])
                            .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Medal.colors(rank)[2].opacity(0.45), radius: 3, y: 2)
                    .offset(y: size * 0.12)
            }
            .frame(width: size, height: size * 1.2)
            .accessibilityHidden(true)
        } else {
            Text(rank.map(String.init) ?? "–")
                .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(me ? Color(hex: 0x1E1340) : style.soft)
                .frame(width: size)
                .accessibilityHidden(true)
        }
    }
}

/// Podium animé : les marches montent (3e, 2e, puis 1er), la couronne tombe sur le 1er, un reflet passe sur les
/// médailles. 2e à gauche, 1er au centre, 3e à droite.
struct PodiumView: View {
    let entries: [RankEntry]
    var style: RankStyle = .onInk
    /// Une place touchée ; nil : podium non touchable.
    var onSelect: ((RankEntry) -> Void)? = nil
    /// 5 du jour (D-091) : une place sans joueur aujourd'hui s'affiche « Place libre ».
    var fillEmpty = false

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ordered: [RankEntry] {
        let byRank = Dictionary(entries.compactMap { e in e.rank.map { ($0, e) } }, uniquingKeysWith: { a, _ in a })
        return [2, 1, 3].compactMap { rank in
            byRank[rank] ?? (fillEmpty ? RankEntry(id: "libre-\(rank)", rank: rank, handle: "Place libre", score: nil,
                                                   totalMs: nil, streak: nil, me: false) : nil)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(ordered) { entry in
                let column = PodiumColumn(entry: entry, style: style, shown: shown || reduceMotion)
                    .frame(maxWidth: .infinity)
                if let onSelect, !entry.me, entry.played {
                    Button { onSelect(entry) } label: { column }
                        .buttonStyle(.row)
                        .accessibilityHint("Ouvre son profil")
                } else {
                    column
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            guard !shown else { return }
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                shown = true
                Haptics.soft()
            }
        }
    }
}

private struct PodiumColumn: View {
    let entry: RankEntry
    let style: RankStyle
    let shown: Bool

    private var rank: Int { entry.rank ?? 3 }
    /// « Place libre » (D-091) : personne n'a encore pris cette place aujourd'hui.
    private var empty: Bool { !entry.played }
    private var height: CGFloat { rank == 1 ? 96 : rank == 2 ? 70 : 54 }
    private var avatar: CGFloat { rank == 1 ? 74 : 56 }
    /// Ordre d'apparition : 3e, 2e, puis 1er.
    private var delay: Double { rank == 3 ? 0 : rank == 2 ? 0.18 : 0.36 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(empty ? AnyShapeStyle(style.text.opacity(0.1))
                                : AnyShapeStyle(LinearGradient(colors: Medal.colors(rank), startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .frame(width: avatar, height: avatar)
                    .overlay(Circle().strokeBorder(entry.me ? Color.sun : style.text.opacity(empty ? 0.35 : 0.8),
                                                   style: StrokeStyle(lineWidth: entry.me ? 3 : 2, dash: empty ? [5, 4] : [])))
                    .overlay {
                        if empty {
                            Text("?")
                                .font(.system(size: avatar * 0.44, weight: .black, design: .rounded))
                                .foregroundStyle(style.soft)
                        } else {
                            // Avatar du joueur (D-113) dans un anneau aux couleurs de la médaille.
                            AnimalBadge(animal: AnimalAvatar(entry.avatar) ?? (entry.me ? MyAvatar.shared.animal : nil)
                                            ?? .fallback(for: entry.handle),
                                        size: avatar - 8)
                        }
                    }
                    .overlay(Shine(active: shown, delay: delay + 0.5).clipShape(Circle()))
                    .shadow(color: Medal.colors(rank)[1].opacity(0.75), radius: shown ? 16 : 0, y: 3)
                    .background {
                        if rank == 1 && !empty {
                            // Rayons de lumière qui tournent doucement derrière le 1er (sans changer la mise en page).
                            LightRays(color: Medal.colors(1)[0])
                                .frame(width: avatar * 2.2, height: avatar * 2.2)
                                .opacity(shown ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(delay + 0.4), value: shown)
                        }
                    }
                if rank == 1 && !empty {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(LinearGradient(colors: Medal.colors(1), startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        .offset(y: shown ? -26 : -70)
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(delay + 0.35), value: shown)
                }
            }
            .padding(.top, rank == 1 ? 22 : 0)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(delay + 0.15), value: shown)
            HStack(spacing: 3) {
                Text(entry.me ? "Toi" : entry.handle)
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(entry.me ? Color.sun : empty ? style.soft : style.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if entry.champion { ArenaCrown(size: 15) }
            }
            if empty {
                Text("Joue pour la prendre !")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(style.soft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let score = entry.score {
                Text("\(score)/5").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(style.text)
            } else if let elo = entry.elo {
                Text(CoteCULT.format(elo)).font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(style.text)
            } else if let points = entry.points {
                Text("\(points) \(entry.unit)").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(style.text)
            }
            if let answers = entry.answers {
                TallyMark(results: answers, onInk: style == .onInk).frame(width: 34)
            }
            if let totalMs = entry.totalMs {
                Text(DurationFormat.clock(milliseconds: totalMs))
                    .font(.system(.caption2, design: .rounded).weight(.bold)).monospacedDigit()
                    .foregroundStyle(style.soft)
            }
            // La marche du podium, aux couleurs de la médaille : elle monte à l'arrivée.
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: Medal.colors(rank).map { $0.opacity(empty ? 0.3 : style == .onInk ? 0.95 : 0.85) },
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Text("\(rank)")
                        .font(.system(size: rank == 1 ? 40 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .padding(.top, 6)
                        .opacity(shown ? 1 : 0)
                }
                .frame(height: shown ? height : 4)
                .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(delay), value: shown)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }


    private var accessibilityText: String {
        if empty { return "\(rank)e place libre : joue pour la prendre" }
        var parts = ["\(rank)e", entry.me ? "toi" : entry.handle]
        if let score = entry.score { parts.append("\(score) sur 5") }
        if let elo = entry.elo { parts.append("Elo \(elo)") }
        if let points = entry.points { parts.append("\(points) points") }
        if let totalMs = entry.totalMs { parts.append(DurationFormat.clock(milliseconds: totalMs)) }
        return parts.joined(separator: ", ")
    }
}

/// Rayons de lumière qui tournent lentement (derrière le 1er du podium).
private struct LightRays: View {
    let color: Color
    @State private var turning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AngularGradient(gradient: Gradient(colors: (0..<12).flatMap { _ in [color.opacity(0.55), .clear] }),
                        center: .center)
            .mask(RadialGradient(colors: [.white, .white.opacity(0.4), .clear], center: .center,
                                 startRadius: 0, endRadius: 90))
            .clipShape(Circle())
            .rotationEffect(.degrees(turning ? 360 : 0))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { turning = true }
            }
    }
}

/// Reflet qui traverse la médaille une fois.
private struct Shine: View {
    let active: Bool
    let delay: Double
    @State private var offset: CGFloat = -1.2

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.45)
                .rotationEffect(.degrees(20))
                .offset(x: offset * proxy.size.width)
        }
        .allowsHitTesting(false)
        .onChange(of: active, initial: true) { _, on in
            guard on else { return }
            withAnimation(.easeInOut(duration: 0.7).delay(delay)) { offset = 1.4 }
        }
    }
}

/// Ligne de classement : médaille en relief (1 à 3) ou rang, pseudo et série, score ou Elo, temps en petit et trait
/// de cinq ; « pas encore joué » grisé ; ta ligne surlignée.
struct RankRow: View {
    let entry: RankEntry
    var style: RankStyle = .onInk
    var showsChevron = false

    var body: some View {
        HStack(spacing: 10) {
            MedalBadge(rank: entry.rank, size: 28, style: style, me: entry.me)
            if entry.showsAvatar {
                ArenaAvatar(handle: entry.handle, size: 34, me: entry.me, avatar: entry.avatar,
                            rank: entry.played ? entry.rank : nil)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(entry.me ? "Toi" : entry.handle)
                        .font(.system(.callout, design: .rounded).weight(.black))
                        .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
                        .lineLimit(1)
                    if entry.champion { ArenaCrown(size: 16) }
                    if let tag = entry.tag {
                        Text(tag)
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(entry.tagFilled ? Color.white : entry.tagColor)
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(entry.tagFilled ? entry.tagColor : entry.tagColor.opacity(0.13), in: Capsule())
                            .layoutPriority(-1)
                    }
                }
                if entry.showsAvatar, let title = PlayerTitle.of(entry.avatar, me: entry.me) {
                    PlayerTitleTag(title: title, compact: true)
                }
                if let streak = entry.streak, streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color(hex: 0xE8452C))
                }
            }
            Spacer(minLength: 4)
            if entry.played {
                VStack(alignment: .trailing, spacing: 2) {
                    if let score = entry.score {
                        Text("\(score)/5")
                            .font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
                    } else if let elo = entry.elo {
                        Text(CoteCULT.format(elo))
                            .font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
                    } else if let points = entry.points {
                        Text("\(points) \(entry.unit)")
                            .font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(entry.me ? Color(hex: 0x1E1340) : style.text)
                    }
                    if let totalMs = entry.totalMs {
                        Text(DurationFormat.clock(milliseconds: totalMs))
                            .font(.system(.caption2, design: .rounded).weight(.bold)).monospacedDigit()
                            .foregroundStyle(entry.me ? Color(hex: 0x1E1340).opacity(0.65) : style.soft)
                    }
                }
                if let answers = entry.answers {
                    TallyMark(results: answers, onInk: style == .onInk && !entry.me).frame(width: 34)
                }
            } else {
                Text("pas encore joué").font(.cfFootnote).foregroundStyle(style.soft)
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(style.soft.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 50)
        .background(entry.me ? Color.sun : style.rowFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(entry.played ? 1 : 0.6)
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

/// Classement complet : podium animé, puis « ··· », toi et tes voisins (lignes qui glissent après le podium).
struct LeaderboardBody: View {
    let entries: [RankEntry]
    var style: RankStyle = .onInk

    @State private var rowsShown = false

    var body: some View {
        let podium = entries.filter { ($0.rank ?? 99) <= 3 }
        let others = entries.filter { ($0.rank ?? 0) > 3 }
        VStack(spacing: 10) {
            if !podium.isEmpty { PodiumView(entries: podium, style: style) }
            if !others.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, entry in
                        let previous = index == 0 ? 3 : (others[index - 1].rank ?? 0)
                        if (entry.rank ?? 0) - previous > 1 { RankGap(style: style) }
                        RankRow(entry: entry, style: style)
                            .scaleEffect(entry.me && rowsShown ? 1.0 : (entry.me ? 0.9 : 1))
                            .offset(x: rowsShown ? 0 : 40)
                            .opacity(rowsShown ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.8 + Double(index) * 0.08),
                                       value: rowsShown)
                    }
                }
            }
        }
        .onAppear {
            guard !rowsShown else { return }
            rowsShown = true
            if others.contains(where: \.me) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { Haptics.selection() }
            }
        }
    }
}

/// Grande carte du classement (D-080) : fond nuit dégradé, halo coloré derrière le podium, titre bien visible.
struct LeaderboardHeroCard<Accessory: View, Content: View>: View {
    var title = "Classement"
    /// Couleur du halo (or si tu es 1er, couleur du domaine…).
    var glow: Color = Color(hex: 0xFFC83D)
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(LinearGradient(colors: Medal.colors(1), startPoint: .top, endPoint: .bottom))
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                accessory
            }
            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1B1040), Color(hex: 0x33186E), Color(hex: 0x5A1F7E)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    RadialGradient(colors: [glow.opacity(0.55), glow.opacity(0.12), .clear], center: .top,
                                   startRadius: 0, endRadius: 220)
                        .frame(height: 260)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: Color(hex: 0x1B1040).opacity(0.35), radius: 14, y: 8)
        .environment(\.colorScheme, .dark)
    }
}

extension LeaderboardHeroCard where Accessory == EmptyView {
    init(title: String = "Classement", glow: Color = Color(hex: 0xFFC83D), @ViewBuilder content: () -> Content) {
        self.init(title: title, glow: glow, accessory: { EmptyView() }, content: content)
    }
}

/// Classement en cours de chargement : un podium et deux lignes fantômes qui scintillent, au lieu d'un vide.
struct LeaderboardSkeleton: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach([2, 1, 3], id: \.self) { rank in
                    VStack(spacing: 6) {
                        Circle().frame(width: rank == 1 ? 74 : 56, height: rank == 1 ? 74 : 56)
                        Capsule().frame(width: 54, height: 10)
                        UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                            .frame(height: rank == 1 ? 96 : rank == 2 ? 70 : 54)
                    }
                    .padding(.top, rank == 1 ? 22 : 0)
                    .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14, style: .continuous).frame(height: 50)
            }
        }
        .foregroundStyle(.white.opacity(pulse ? 0.16 : 0.08))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement du classement")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true }
        }
    }
}
