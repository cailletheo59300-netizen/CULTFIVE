import SwiftUI
import CultFiveCore

/// Classement complet de l'Arène : semaine (toute l'Arène), amis (semaine), depuis toujours (victoires). Podium animé,
/// puis les autres places ; en bas, ce que rapporte chaque place le lundi.
struct ArenaLeaderboardView: View {
    @Environment(AppModel.self) private var app
    @State private var scope: ArenaLeaderboard.Scope = .week
    @State private var boards: [ArenaLeaderboard.Scope: ArenaLeaderboard] = [:]
    @State private var loading = false

    private var board: ArenaLeaderboard? { boards[scope] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Picker("Classement", selection: $scope) {
                    Text("Semaine").tag(ArenaLeaderboard.Scope.week)
                    Text("Amis").tag(ArenaLeaderboard.Scope.friends)
                    Text("Depuis toujours").tag(ArenaLeaderboard.Scope.all)
                }
                .pickerStyle(.segmented)

                header

                VStack(spacing: 10) {
                    if let board {
                        if entries(board).isEmpty {
                            empty
                        } else {
                            LeaderboardBody(entries: entries(board), style: .onInk)
                                .id(scope)
                        }
                    } else {
                        ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(16)
                .background(ArenaPalette.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                if scope != .all {
                    Text("5 duels au moins dans la semaine pour être classé devant les autres. Égalité de points : la victoire en plus, puis le premier arrivé.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if scope == .week, let prizes = board?.prizes, !prizes.isEmpty {
                    ArenaPrizesList(prizes: prizes)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.l)
        }
        .scrollIndicators(.hidden)
        .clearsTabBar()
        .background(Color.paper)
        .navigationTitle("Classement")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scope) { await load() }
        .refreshable { boards[scope] = nil; await load() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: scope == .all ? "infinity" : "calendar")
                .font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.brand)
            Text(scope == .all ? "Classés aux victoires, depuis le début" : "Classés aux points de la semaine")
                .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
            Spacer()
            if scope != .all, let end = board?.endsAt {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("Fin dans \(ArenaClock.remaining(until: end, now: context.date))")
                        .font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.inkSoft)
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                ForEach([2, 1, 3], id: \.self) { rank in ArenaMedal(rank: rank, size: rank == 1 ? 64 : 50).opacity(0.5) }
            }
            Text(scope == .friends ? "Aucun de tes amis n'a encore joué en Arène cette semaine." : "Personne n'a encore de points : la 1re place t'attend.")
                .font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    /// Le haut du classement, puis toi et tes voisins s'ils sont plus loin.
    private func entries(_ board: ArenaLeaderboard) -> [RankEntry] {
        let unit = scope == .all ? "victoires" : "pts"
        func entry(_ row: ArenaRow) -> RankEntry {
            RankEntry(id: row.id.uuidString, rank: row.rank, handle: row.handle, score: nil, totalMs: nil, streak: nil, me: row.me,
                      points: scope == .all ? row.wins : row.points, champion: row.champion, unit: unit,
                      avatar: row.avatar, showsAvatar: true)
        }
        var rows = Array(board.rows.prefix(30)).map(entry)
        if let me = board.me, !rows.contains(where: { $0.me }) { rows.append(entry(me)) }
        return rows
    }

    private func load() async {
        guard boards[scope] == nil else { return }
        let wanted = scope
        if let fresh = try? await app.service.arenaLeaderboard(wanted) { boards[wanted] = fresh }
    }
}

/// Les récompenses du lundi, place par place.
struct ArenaPrizesList: View {
    let prizes: [ArenaPrize]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Récompenses du lundi").font(.cfHeadline)
            Text("Chaque lundi matin, tout le monde reçoit sa récompense selon sa place de la semaine. Plus tu montes, plus elle est grosse.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(Array(prizes.enumerated()), id: \.offset) { _, prize in
                    row(prize)
                }
            }
        }
    }

    private func row(_ prize: ArenaPrize) -> some View {
        let top = prize.from ?? 99
        return HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                if top <= 3 {
                    ArenaMedal(rank: top, size: top == 1 ? 52 : 44)
                } else {
                    Text(ArenaClock.places(prize))
                        .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 66)
            ArenaPrizeStrip(prize: prize, itemSize: top == 1 ? 44 : 36)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(top == 1 ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF6D6), Color(hex: 0xFFE9A8)],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                             : AnyShapeStyle(Color.paperRaised),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(top == 1 ? Color(hex: 0xF2B705).opacity(0.6) : Color.hairline, lineWidth: top == 1 ? 1.5 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ArenaClock.places(prize))")
    }
}

/// Feuille « Récompenses du lundi », depuis l'onglet Arène.
struct ArenaPrizesSheet: View {
    let prizes: [ArenaPrize]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ArenaPrizesList(prizes: prizes)
                    .padding(Space.gutter)
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

/// Le lundi : la semaine est finie, voici ta place et tes récompenses.
struct ArenaWeekRewardView: View {
    let reward: ArenaWeekReward
    let onCollect: () -> Void

    @State private var shown = false

    private var podium: Bool { reward.eligible && reward.rank <= 3 }

    var body: some View {
        ZStack {
            ArenaPalette.night.ignoresSafeArea()
            if reward.eligible && reward.rank <= 15 { Confetti().ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: Space.l) {
                Spacer()
                Text("Semaine terminée").labelCaps(Color.sun)
                Group {
                    if reward.rank == 1 && reward.eligible {
                        ZStack(alignment: .top) {
                            ArenaMedal(rank: 1, size: 170)
                            ArenaCrown(size: 90).offset(y: -62)
                        }
                    } else if podium {
                        ArenaMedal(rank: reward.rank, size: 170)
                    } else {
                        ArenaCrest().frame(width: 150)
                    }
                }
                .scaleEffect(shown ? 1 : 0.4)
                .opacity(shown ? 1 : 0)
                Text(headline)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                ArenaPrizeStrip(prize: reward.prizes, onInk: true, itemSize: 60)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Spacer()
                Button(action: onCollect) { Text("Récupérer") }
                    .buttonStyle(.sun)
            }
            .padding(Space.gutter)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) { shown = true }
            Haptics.success()
        }
    }

    private var headline: String {
        guard reward.eligible, reward.rank <= 15 else { return "Merci d'avoir joué !" }
        return reward.rank == 1 ? "Champion de l'Arène !" : "Tu finis \(ArenaClock.ordinal(reward.rank)) !"
    }

    private var detail: String {
        if reward.eligible && reward.rank == 1 {
            return "\(reward.points) points : personne n'a fait mieux. Ta couronne brille toute la semaine."
        }
        if reward.eligible { return "\(reward.points) points cette semaine. Nouvelle semaine, nouveau classement : à toi de monter !" }
        return "Voici ton coffre de la semaine. Joue 5 duels pour entrer au classement des grosses récompenses."
    }
}
