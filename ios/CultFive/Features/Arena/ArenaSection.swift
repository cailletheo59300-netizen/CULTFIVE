import SwiftUI
import CultFiveCore

/// Haut de l'onglet Arène : la semaine du joueur, les deux gros boutons (« Contre un joueur » : duel classé ; « Contre
/// un ami » : D-112) et le coffre d'Arène, le mini-classement (Monde | Amis ; les récompenses sont dans « Tout voir »)
/// et « Mes duels ». Le reste de l'onglet (amis, duels entre amis, ligues) suit en dessous.
struct ArenaSection: View {
    @Environment(AppModel.self) private var app
    @Binding var overview: ArenaOverview?
    /// Avec des amis, le mini-classement s'ouvre sur « Amis ».
    var hasFriends = false
    let onPlay: () -> Void
    let onFriend: () -> Void
    let onLeaderboard: () -> Void
    let onDuel: (ArenaDuel) -> Void

    enum BoardScope: String, CaseIterable { case world = "Monde", friends = "Amis" }

    @State private var scope: BoardScope?
    @State private var friendsBoard: ArenaLeaderboard?
    @State private var showChestInfo = false

    private var currentScope: BoardScope { scope ?? (hasFriends ? .friends : .world) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if let champion = overview?.champion {
                championBanner(champion)
            }
            hero
            leaderboardTeaser
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
                        if data.streak > 0 {
                            HStack(spacing: 3) {
                                GameIcon.flame.image.frame(width: 18, height: 18)
                                Text("\(data.streak)").font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: 0xF76707).opacity(0.35), in: Capsule())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(data.streak) victoires de suite")
                        }
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

            HStack(spacing: 12) {
                Button(action: onPlay) {
                    ArenaChoiceLabel(title: "Contre un joueur", icon: .swords, dot: data.waiting > 0)
                }
                .buttonStyle(ArenaChoiceStyle(colors: [Color(hex: 0xFFE066), Color(hex: 0xFFB800)], text: Color(hex: 0x1E1340),
                                              glow: Color(hex: 0xFFC933), pulses: true))
                .accessibilityHint("Duel classé : il rapporte des points de la semaine")
                Button(action: onFriend) {
                    ArenaChoiceLabel(title: "Contre un ami", icon: .friends, dot: false)
                }
                .buttonStyle(ArenaChoiceStyle(colors: [Color(hex: 0xFF7AB6), Color(hex: 0xA34DFF)], text: .white,
                                              glow: Color(hex: 0xFF5FA2), pulses: false))
                .accessibilityHint("Défie un ami, pour l'honneur")
            }

            chestButton
        }
        .padding(18)
        .background(ArenaPalette.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(hex: 0x2A1680).opacity(0.35), radius: 18, y: 10)
        .sheet(isPresented: $showChestInfo) { ArenaChestInfoSheet(progress: data.chest.progress, goal: data.chest.goal) }
    }

    /// Coffre d'Arène : la jauge, et en touchant, ce qu'il contient.
    private var chestButton: some View {
        Button { showChestInfo = true } label: {
            HStack(spacing: 12) {
                ChestView(tier: .gold).frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Coffre d'Arène").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                        Spacer()
                        Text("\(data.chest.progress)/\(data.chest.goal) victoires")
                            .font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(Color.sun)
                    }
                    ProgressBarLine(value: Double(data.chest.progress) / Double(max(data.chest.goal, 1)))
                }
                Image(systemName: "info.circle.fill").font(.title3).foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coffre d'Arène, \(data.chest.progress) victoires sur \(data.chest.goal)")
        .accessibilityHint("Voir ce qu'il contient")
        .accessibilityAddTraits(.isButton)
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

    // MARK: Mes duels

    @ViewBuilder private var myDuels: some View {
        if !data.duels.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Mes duels classés").labelCaps()
                VStack(spacing: 0) {
                    ForEach(Array(data.duels.prefix(8).enumerated()), id: \.element.id) { index, duel in
                        if index > 0 { Hairline().padding(.leading, 60) }
                        Button { onDuel(duel) } label: { ArenaDuelRow(duel: duel, isNew: ArenaSeen.isNew(duel)) }
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
    /// Résultat arrivé depuis la dernière visite.
    var isNew = false

    var body: some View {
        HStack(spacing: 12) {
            if let opponent = duel.opponent, duel.isFinished {
                ArenaAvatar(handle: opponent.handle, size: 38)
            } else if duel.myTurn {
                ArenaCrest().frame(width: 38, height: 38)
            } else {
                ArenaMystery(size: 38, onInk: false)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ArenaHandle(handle: duel.isFinished ? (duel.opponent?.handle ?? "Duel classé")
                                                        : duel.myTurn ? "Duel classé" : "Adversaire en route",
                                champion: duel.isFinished && (duel.opponent?.champion ?? false))
                    if isNew {
                        Text("Nouveau !")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0x1E1340))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.sun, in: Capsule())
                    }
                }
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
            return "Toi \(duel.me.score)/\(duel.total) · tu seras prévenu"
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

/// Contenu d'un gros bouton de l'Arène : l'icône 3D, le titre.
private struct ArenaChoiceLabel: View {
    let title: String
    let icon: ArenaButtonIcon.Kind
    let dot: Bool

    var body: some View {
        VStack(spacing: 4) {
            ArenaButtonIcon(kind: icon)
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
                .overlay(alignment: .topTrailing) {
                    if dot {
                        Circle().fill(Color.correct).frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .accessibilityLabel("Un adversaire t'attend")
                    }
                }
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.black))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10).padding(.bottom, 12)
    }
}

/// Gros bouton de l'Arène : dégradé vif, liseré clair en haut, ombre colorée, s'enfonce quand on appuie ;
/// « Contre un joueur » respire doucement pour appeler le doigt.
private struct ArenaChoiceStyle: ButtonStyle {
    let colors: [Color]
    let text: Color
    let glow: Color
    let pulses: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChoiceBody(configuration: configuration, colors: colors, text: text, glow: glow, pulses: pulses)
    }

    private struct ChoiceBody: View {
        let configuration: ButtonStyleConfiguration
        let colors: [Color]
        let text: Color
        let glow: Color
        let pulses: Bool
        @State private var breathe = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            configuration.label
                .foregroundStyle(text)
                .background(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), in: shape)
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0)], startPoint: .top,
                                                           endPoint: .center), lineWidth: 1.5))
                .shadow(color: glow.opacity(configuration.isPressed ? 0.2 : (breathe ? 0.75 : 0.4)),
                        radius: breathe ? 16 : 10, y: configuration.isPressed ? 2 : 7)
                .scaleEffect(configuration.isPressed ? 0.95 : (breathe ? 1.02 : 1))
                .offset(y: configuration.isPressed ? 3 : 0)
                .animation(Motion.press, value: configuration.isPressed)
                .contentShape(shape)
                .onAppear {
                    guard pulses, !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathe = true }
                }
        }
    }
}

/// Ce que contient le coffre d'Arène et comment le gagner.
struct ArenaChestInfoSheet: View {
    let progress: Int
    let goal: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.l) {
            ChestView(tier: .gold).frame(width: 130, height: 130).padding(.top, Space.l)
            VStack(spacing: 6) {
                Text("Coffre d'Arène").font(.cfDisplay)
                Text("Gagne \(goal) duels classés : un coffre en or s'ouvre, avec une carte rare ou mieux à l'intérieur.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                ProgressBarLine(value: Double(progress) / Double(max(goal, 1)), fill: Color.sun, track: Color.hairline)
                Text(progress >= goal ? "Prêt !" : "Encore \(max(goal - progress, 0)) victoire\(goal - progress > 1 ? "s" : "")")
                    .font(.system(.headline, design: .rounded).weight(.black))
            }
            VStack(alignment: .leading, spacing: 10) {
                bonus("Ton 1er duel gagné du jour", "coffre d'argent")
                bonus("5 victoires de suite", "coffre d'argent")
            }
            .popCard(padding: 14, radius: 18)
            Spacer(minLength: 0)
            Button("Compris") { dismiss() }.buttonStyle(.ink)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.m)
        .background(Color.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func bonus(_ what: String, _ reward: String) -> some View {
        HStack(spacing: 10) {
            ChestView(tier: .silver).frame(width: 30, height: 30)
            Text(what).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
            Spacer()
            Text(reward).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkSoft)
        }
    }
}

/// Résultats de duels classés déjà vus sur cet appareil : un résultat arrivé depuis s'affiche « Nouveau ! ».
enum ArenaSeen {
    private static let key = "arena.seenResults"
    private static let primedKey = "arena.seenPrimed"

    private static var ids: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    /// Première fois : les résultats déjà là ne sont pas « nouveaux ».
    static func prime(_ duels: [ArenaDuel]) {
        guard !UserDefaults.standard.bool(forKey: primedKey) else { return }
        UserDefaults.standard.set(true, forKey: primedKey)
        duels.filter(\.isFinished).forEach { mark($0.id) }
    }

    static func isNew(_ duel: ArenaDuel) -> Bool {
        duel.isFinished && !ids.contains(duel.id.uuidString)
    }

    static func mark(_ id: UUID) {
        var list = ids
        guard !list.contains(id.uuidString) else { return }
        list.append(id.uuidString)
        UserDefaults.standard.set(Array(list.suffix(200)), forKey: key)
    }
}
