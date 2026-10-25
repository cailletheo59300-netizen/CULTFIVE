import SwiftUI
import CultFiveCore

/// Haut de l'onglet Arène : la semaine du joueur et les deux boutons (« Contre un joueur » : duel classé ; « Contre un
/// ami » : D-112), le mini-classement (Monde | Amis), les récompenses de la semaine et « Mes duels ». Le reste de
/// l'onglet (amis, duels entre amis, ligues) suit en dessous.
struct ArenaSection: View {
    @Environment(AppModel.self) private var app
    @Binding var overview: ArenaOverview?
    /// Avec des amis, le mini-classement s'ouvre sur « Amis ».
    var hasFriends = false
    let onPlay: () -> Void
    let onFriend: () -> Void
    let onLeaderboard: () -> Void
    let onPrizes: () -> Void
    let onDuel: (ArenaDuel) -> Void

    enum BoardScope: String, CaseIterable { case world = "Monde", friends = "Amis" }

    @State private var scope: BoardScope?
    @State private var friendsBoard: ArenaLeaderboard?

    private var currentScope: BoardScope { scope ?? (hasFriends ? .friends : .world) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if let champion = overview?.champion {
                championBanner(champion)
            }
            hero
            leaderboardTeaser
            prizesCard
            myDuels
        }
    }

    private var data: ArenaOverview { overview ?? ArenaOverview() }

    // MARK: Champion

    private func championBanner(_ champion: ArenaOverview.Champion) -> some View {
        HStack(spacing: 10) {
            ArenaCrown(size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("Champion de la semaine").labelCaps()
                Text(champion.id == app.profile?.id ? "C'est toi ! Ta couronne brille toute la semaine." : champion.handle)
                    .font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    .lineLimit(2)
            }
            Spacer()
        }
        .popCard(padding: 12, radius: 18)
        .accessibilityElement(children: .combine)
    }

    // MARK: Ma semaine

    private var hero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ArenaCrest().frame(width: 92, height: 98)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ta semaine").labelCaps(.white.opacity(0.65))
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(data.me.points)")
                            .font(.system(size: 40, weight: .black, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("pts").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.8))
                    }
                    Text(rankLine).font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(Color.sun)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label("Fin dans \(ArenaClock.remaining(until: data.endsAt, now: context.date))", systemImage: "clock")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                tile {
                    HStack(spacing: 8) {
                        GameIcon.flame.image.frame(width: 26, height: 26).saturation(data.streak > 0 ? 1 : 0)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(data.streak > 0 ? "\(data.streak) de suite" : "Pas de série")
                                .font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                            Text(data.streak >= data.rules.streakFrom ? "+1 pt par victoire" : "dès 3 : +1 pt par victoire")
                                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }
                tile {
                    HStack(spacing: 8) {
                        ChestView(tier: .gold).frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coffre d'Arène \(data.chest.progress)/\(data.chest.goal)")
                                .font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            ProgressBarLine(value: Double(data.chest.progress) / Double(max(data.chest.goal, 1)))
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: onPlay) {
                        bigLabel("Contre un joueur", detail: "classé · points", symbol: "globe.europe.africa.fill",
                                 dot: data.waiting > 0)
                    }
                    .buttonStyle(ArenaChoiceStyle(fill: Color.sun, text: Color(hex: 0x1E1340)))
                    .accessibilityHint(data.waiting > 0 ? "Un adversaire t'attend déjà" : "Duel classé, il rapporte des points")
                    Button(action: onFriend) {
                        bigLabel("Contre un ami", detail: "pour l'honneur", symbol: "person.2.fill", dot: false)
                    }
                    .buttonStyle(ArenaChoiceStyle(fill: .white.opacity(0.14), text: .white, stroke: .white.opacity(0.22)))
                    .accessibilityHint("Défie un ami, sans points de la semaine")
                }
                Text(subtitle)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(ArenaPalette.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(hex: 0x2A1680).opacity(0.35), radius: 18, y: 10)
    }

    private func bigLabel(_ title: String, detail: String, symbol: String, dot: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 22, weight: .bold))
                .overlay(alignment: .topTrailing) {
                    if dot {
                        Circle().fill(Color.correct).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.correct.opacity(0.4), lineWidth: 4))
                            .offset(x: 6, y: -3)
                    }
                }
            Text(title).font(.system(.callout, design: .rounded).weight(.black)).lineLimit(1).minimumScaleFactor(0.75)
            Text(detail).font(.system(size: 11, weight: .bold, design: .rounded)).opacity(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
    }

    private var rankLine: String {
        let me = data.me
        if me.duels == 0 { return "Joue ton 1er duel de la semaine" }
        if !me.eligible {
            let left = max(me.minDuels - me.duels, 1)
            return "Encore \(left) duel\(left > 1 ? "s" : "") pour entrer au classement"
        }
        guard let rank = me.rank else { return "" }
        return "\(ArenaClock.ordinal(rank)) sur \(data.players)"
    }

    private var subtitle: String {
        var parts = ["\(data.rules.questions) questions · \(data.rules.seconds) s chacune"]
        parts.append(data.dailyChest ? "1er duel gagné du jour = coffre d'argent" : "+\(data.rules.win) pts par victoire")
        return parts.joined(separator: " · ")
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Mini-classement

    private var leaderboardTeaser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onLeaderboard) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(LinearGradient(colors: Medal.colors(1), startPoint: .top, endPoint: .bottom))
                    Text("Classement de la semaine").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer()
                    Text("Tout voir").font(.system(.footnote, design: .rounded).weight(.black)).foregroundStyle(Color.brand)
                    Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(Color.brand)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.row)
            scopePicker
            Button(action: onLeaderboard) {
                VStack(alignment: .leading, spacing: 12) {
                    if currentScope == .friends {
                        friendsTeaser
                    } else if data.top.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { rank in
                                VStack(spacing: 6) {
                                    ArenaMedal(rank: rank, size: 44).opacity(0.5)
                                    Text("Place libre").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        Text("Personne n'a encore de points cette semaine : prends la tête !")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(data.top) { row in teaserRow(row) }
                            if let rank = data.me.rank, rank > 3 {
                                RankGap(style: .onPaper)
                                teaserRow(ArenaRow(rank: rank, id: app.profile?.id ?? UUID(), handle: "Toi", points: data.me.points,
                                                   eligible: data.me.eligible, me: true, champion: data.me.champion))
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.row)
        }
        .popCard(padding: 16, radius: 22)
    }

    /// Monde | Amis : deux pastilles, hors des boutons qui ouvrent le classement complet.
    private var scopePicker: some View {
        HStack(spacing: 6) {
            ForEach(BoardScope.allCases, id: \.self) { item in
                let on = item == currentScope
                Button {
                    Haptics.selection()
                    withAnimation(Motion.bounce) { scope = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(.footnote, design: .rounded).weight(.black))
                        .foregroundStyle(on ? Color.white : Color.ink)
                        .padding(.horizontal, 14).frame(minHeight: 32)
                        .background(on ? Color.brand : Color.paper, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.row)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer()
        }
        .task(id: currentScope) {
            guard currentScope == .friends, friendsBoard == nil else { return }
            friendsBoard = try? await app.service.arenaLeaderboard(.friends)
        }
    }

    @ViewBuilder private var friendsTeaser: some View {
        if let board = friendsBoard {
            let rows = Array(board.rows.prefix(3))
            if rows.isEmpty || !hasFriends {
                Text(hasFriends ? "Aucun ami n'a encore joué de duel classé cette semaine. Montre-leur l'exemple !"
                                : "Ajoute des amis pour vous comparer ici chaque semaine.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in teaserRow(row) }
                    if let me = board.me, !rows.contains(where: { $0.me }) {
                        RankGap(style: .onPaper)
                        teaserRow(me)
                    }
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 60)
        }
    }

    private func teaserRow(_ row: ArenaRow) -> some View {
        HStack(spacing: 10) {
            ArenaMedal(rank: row.rank, size: 34)
            ArenaHandle(handle: row.me ? "Toi" : row.handle, champion: row.champion,
                        color: row.me ? Color(hex: 0x1E1340) : .ink)
            Spacer()
            Text("\(row.points) pts").font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(row.me ? Color(hex: 0x1E1340) : .ink)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(row.me ? Color.sun : Color.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Récompenses

    /// Ce que rapporte la semaine : le 1er en grand, puis ce que vaut ma place actuelle.
    private var prizesCard: some View {
        Button(action: onPrizes) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Récompenses du lundi").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    Spacer()
                    Text("Détail").font(.system(.footnote, design: .rounded).weight(.black)).foregroundStyle(Color.brand)
                    Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(Color.brand)
                }
                if let first = data.prizes.first {
                    HStack(alignment: .top, spacing: 12) {
                        ArenaMedal(rank: 1, size: 46)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Le 1er de la semaine").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                            ScrollView(.horizontal, showsIndicators: false) {
                                ArenaPrizeStrip(prize: first, itemSize: 34)
                            }
                        }
                    }
                }
                Text(myPrizeLine)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .popCard(padding: 16, radius: 22)
        }
        .buttonStyle(.row)
    }

    private var myPrizeLine: String {
        let me = data.me
        if !me.eligible { return "Top 3 : gros lots · top 10 et 15 : coffres et pochettes · tous les joueurs : au moins un coffre en bois. 5 duels dans la semaine pour être classé." }
        guard let rank = me.rank else { return "" }
        if rank <= 15 { return "À ta place (\(ArenaClock.ordinal(rank))), tu gagnerais : \(summary(prize(for: rank)))." }
        return "Entre dans le top 15 pour des coffres d'argent, d'or et des pochettes."
    }

    private func prize(for rank: Int) -> ArenaPrize? {
        data.prizes.first { p in
            guard let from = p.from else { return false }
            return rank >= from && rank <= (p.to ?? Int.max)
        }
    }

    private func summary(_ prize: ArenaPrize?) -> String {
        guard let prize else { return "un coffre en bois" }
        var parts: [String] = []
        if let n = prize.gold, n > 0 { parts.append(n > 1 ? "\(n) coffres en or" : "1 coffre en or") }
        if let n = prize.silver, n > 0 { parts.append(n > 1 ? "\(n) coffres d'argent" : "1 coffre d'argent") }
        if let card = prize.card { parts.append(card == "legend" ? "une carte légendaire" : "une carte épique") }
        if let n = prize.packs, n > 0 { parts.append(n > 1 ? "\(n) pochettes" : "1 pochette") }
        if let n = prize.seeds, n > 0 { parts.append("\(n) neurones") }
        if prize.crown == true { parts.append("la couronne") }
        return parts.isEmpty ? "un coffre en bois" : parts.joined(separator: ", ")
    }

    // MARK: Mes duels

    @ViewBuilder private var myDuels: some View {
        if !data.duels.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Mes duels classés").labelCaps()
                VStack(spacing: 0) {
                    ForEach(Array(data.duels.prefix(8).enumerated()), id: \.element.id) { index, duel in
                        if index > 0 { Hairline().padding(.leading, 60) }
                        Button { onDuel(duel) } label: { ArenaDuelRow(duel: duel) }
                            .buttonStyle(.row)
                    }
                }
                .popCard(padding: 0, radius: 20)
            }
        }
    }
}

/// Une ligne de « Mes duels » : adversaire, état, score et points.
struct ArenaDuelRow: View {
    let duel: ArenaDuel

    var body: some View {
        HStack(spacing: 12) {
            if let opponent = duel.opponent, duel.isFinished {
                ArenaAvatar(handle: opponent.handle, size: 38)
            } else {
                ArenaCrest().frame(width: 38, height: 38)
            }
            VStack(alignment: .leading, spacing: 2) {
                ArenaHandle(handle: duel.isFinished ? (duel.opponent?.handle ?? "Duel classé") : "Duel classé",
                            champion: duel.isFinished && (duel.opponent?.champion ?? false))
                Text(detail).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(detailColor)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        if duel.myTurn { return "À finir : touche pour reprendre" }
        switch duel.winner {
        case "me": return "Gagné \(duel.me.score) – \(duel.opponent?.score ?? 0)"
        case "opponent": return "Perdu \(duel.me.score) – \(duel.opponent?.score ?? 0)"
        case "draw": return "Égalité \(duel.me.score) – \(duel.opponent?.score ?? 0)"
        default:
            return "\(duel.me.score)/\(duel.total) · résultat bientôt"
        }
    }

    private var detailColor: Color {
        switch duel.winner {
        case "me": return .correct
        case "opponent": return .wrong
        default: return duel.myTurn ? Color(hex: 0xF76707) : .inkSoft
        }
    }

    @ViewBuilder private var trailing: some View {
        if let points = duel.result?.points, duel.isFinished {
            Text(points > 0 ? "+\(points) pts" : "0 pt")
                .font(.system(.footnote, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(points > 0 ? Color(hex: 0x1E1340) : Color.inkSoft)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(points > 0 ? Color.sun : Color.hairline, in: Capsule())
        } else if duel.myTurn {
            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Color.brand)
        } else {
            Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(Color.inkSoft)
        }
    }
}

/// Gros bouton de choix sous le blason (Contre un joueur / Contre un ami).
private struct ArenaChoiceStyle: ButtonStyle {
    let fill: Color
    let text: Color
    var stroke: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.horizontal, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
