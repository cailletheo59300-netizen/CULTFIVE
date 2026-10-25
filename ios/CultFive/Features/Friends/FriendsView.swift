import SwiftUI
import CultFiveCore

/// Arène (D-111) : en haut, le duel classé (ma semaine, les boutons « Contre un joueur » / « Contre un ami », le
/// coffre d'Arène, le mini-classement, mes duels classés). Puis « Entre amis » (D-112), épuré : le titre et
/// « Historique », la rangée de mes amis avec leur 5 du jour (ou la carte d'invitation), ce qui attend le joueur
/// (demandes, duels à jouer), ses ligues. Toutes les actions sur un ami (duel, face-à-face, retirer) sont dans son
/// profil ; les actions globales (ajouter, défier par lien, ligues) dans le bouton « + ».
struct FriendsView: View {
    enum Route: Hashable {
        case league(UUID)
        case friend(UUID, String)
        case arenaLeaderboard
        case duelHistory
    }

    @Environment(AppModel.self) private var app
    @State private var overview: FriendsOverview?
    @State private var leagues: [LeagueSummary] = []
    @State private var referral: ReferralOverview?
    @State private var showSearch = false
    @State private var showNewLeague = false
    @State private var showLinkDuel = false
    @State private var joinCode = ""
    @State private var showJoin = false
    @State private var path: [Route] = []
    @State private var duels: [Duel] = []
    @State private var activeDuel: DuelLaunch?
    @State private var pendingLaunch: DuelLaunch?
    /// Code de ligue à confirmer (saisi ou reçu par lien) : aperçu avant de rejoindre.
    @State private var joinRequest: LeagueJoinRequest?
    @State private var arena: ArenaOverview?
    @State private var showArena = false
    @State private var arenaDetail: ArenaDuel?
    /// Récompenses de la semaine passée, pas encore montrées.
    @State private var weekReward: ArenaRewardItem?
    @State private var showChallenge = false
    /// « Ajouter un ami » touché dans la feuille « Contre un ami » : ouvert une fois la feuille refermée.
    @State private var searchAfterChallenge = false

    /// Duels qui attendent le joueur, ou un adversaire par lien.
    private var waitingDuels: [Duel] {
        duels.filter { $0.myTurn || ($0.status == "open" && $0.opponent == nil) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Arène").font(.cfDisplay)
                            Spacer()
                            TourButton(id: .friends)
                            addMenu
                        }
                        Text("Affronte n'importe qui pour le classement de la semaine, ou défie tes amis.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Space.l)

                    ArenaSection(overview: $arena,
                                 hasFriends: !(overview?.friends.isEmpty ?? true),
                                 onPlay: { Haptics.soft(); showArena = true },
                                 onFriend: { Haptics.soft(); showChallenge = true },
                                 onLeaderboard: { path.append(.arenaLeaderboard) },
                                 onDuel: { duel in
                                     if duel.myTurn { showArena = true } else { arenaDetail = duel }
                                 })

                    VStack(alignment: .leading, spacing: Space.m) {
                        friendsTitle
                        if app.isAnonymous {
                            AccountNudge()
                        }
                        friendsHeader
                    }
                    toPlay
                    leaguesBlock
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
            .clearsTabBar()
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .guidedTour(.friends)
            .refreshable { await load() }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .league(let id): LeagueView(leagueId: id)
                case .friend(let id, let handle): FriendProfileView(friendId: id, handle: handle)
                case .arenaLeaderboard: ArenaLeaderboardView()
                case .duelHistory: DuelHistoryView()
                }
            }
        }
        .sheet(isPresented: $showSearch, onDismiss: { Task { await load() } }) {
            AddFriendSheet()
        }
        .sheet(isPresented: $showChallenge, onDismiss: {
            if let launch = pendingLaunch {
                pendingLaunch = nil
                activeDuel = launch
            } else if searchAfterChallenge {
                searchAfterChallenge = false
                showSearch = true
            }
        }) {
            FriendChallengeSheet(friends: overview?.friends ?? [], duels: duels, onCreated: { duel in
                pendingLaunch = DuelLaunch(id: duel.id)
                showChallenge = false
                app.askNotificationsAfterSocial()
            }, onAddFriend: { searchAfterChallenge = true })
        }
        .sheet(isPresented: $showNewLeague) {
            NewLeagueSheet { standings in
                showNewLeague = false
                Task {
                    await load()
                    path.append(.league(standings.id))
                }
            }
        }
        .sheet(isPresented: $showLinkDuel, onDismiss: {
            if let launch = pendingLaunch {
                pendingLaunch = nil
                activeDuel = launch
            }
        }) {
            DuelSetupSheet(opponentName: nil, friendId: nil) { duel in
                pendingLaunch = DuelLaunch(id: duel.id)
                showLinkDuel = false
                app.askNotificationsAfterSocial()
            }
        }
        .alert("Rejoindre une ligue", isPresented: $showJoin) {
            TextField("Code", text: $joinCode).textInputAutocapitalization(.characters)
            Button("Continuer") {
                let code = joinCode.trimmingCharacters(in: .whitespaces)
                if !code.isEmpty { joinRequest = LeagueJoinRequest(code: code) }
            }
            Button("Annuler", role: .cancel) {}
        }
        .task {
            await load()
            #if DEBUG
            if Demo.screen == .league, let first = leagues.first { path.append(.league(first.id)) }
            #endif
        }
        .fullScreenCover(item: $activeDuel, onDismiss: { Task { await load() } }) { launch in
            DuelSessionView(duelId: launch.id)
        }
        .fullScreenCover(isPresented: $showArena, onDismiss: {
            Task {
                await load()
                app.openNewChests()
            }
        }) {
            ArenaSessionView()
        }
        .sheet(item: $arenaDetail) { duel in
            ArenaDuelDetail(duel: duel) {
                arenaDetail = nil
                Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    showArena = true
                }
            }
        }
        .fullScreenCover(item: $weekReward) { item in
            let reward = item.reward
            ArenaWeekRewardView(reward: reward) {
                weekReward = nil
                Task {
                    try? await app.service.arenaRewardSeen(week: reward.week)
                    await app.refreshProgression()
                    await AlbumStore.shared.refresh()
                    app.openNewChests()
                    await load()
                }
            }
        }
        .sheet(item: $joinRequest) { request in
            LeagueJoinSheet(code: request.code) { standings in
                joinRequest = nil
                app.askNotificationsAfterSocial()
                Task {
                    await load()
                    path.append(.league(standings.id))
                }
            }
        }
        .task(id: app.pendingDuelId) {
            if let id = app.pendingDuelId {
                app.pendingDuelId = nil
                activeDuel = DuelLaunch(id: id)
            }
        }
        .onChange(of: app.reselected[.friends]) { path = [] }
        .task(id: app.pendingLeagueId) {
            if let id = app.pendingLeagueId {
                app.pendingLeagueId = nil
                path = [.league(id)]
            }
        }
        .task(id: app.pendingDuelCode) {
            if let code = app.pendingDuelCode {
                app.pendingDuelCode = nil
                do {
                    let duel = try await app.service.duelJoin(code: code)
                    await load()
                    activeDuel = DuelLaunch(id: duel.id)
                } catch {
                    app.show(error, "Ce défi n'est plus disponible.")
                }
            }
        }
        .task(id: app.pendingLeagueCode) {
            if let code = app.pendingLeagueCode {
                app.pendingLeagueCode = nil
                joinRequest = LeagueJoinRequest(code: code)
            }
        }
    }

    private func load() async {
        let service = app.service
        async let friends = try? service.friends()
        async let mine = try? service.leagues()
        async let referralInfo = try? service.referralOverview()
        async let myDuels = try? service.duels()
        async let arenaData = try? service.arenaOverview()
        if let fresh = await arenaData {
            arena = fresh
            ArenaSeen.prime(fresh.duels)
            if weekReward == nil, let reward = fresh.reward { weekReward = ArenaRewardItem(reward: reward) }
            app.markArenaSeen(fresh)
        }
        duels = await myDuels ?? []
        overview = await friends
        leagues = await mine ?? []
        referral = await referralInfo
    }


    // MARK: Blocs

    private var addMenu: some View {
        Menu {
            Button("Ajouter un ami", systemImage: "person.badge.plus") { showSearch = true }
            if let code = referral?.code ?? app.profile?.referralCode {
                ShareLink(item: Brand.inviteURL(code: code),
                          message: Text("Viens me défier sur \(Brand.name) ! 7 questions, 25 s chacune.")) {
                    Label("Inviter un ami", systemImage: "square.and.arrow.up")
                }
            }
            Button("Défier par lien", systemImage: "link") { showLinkDuel = true }
            Divider()
            Button("Créer une ligue", systemImage: "trophy") { showNewLeague = true }
            Button("Rejoindre une ligue", systemImage: "number") { joinCode = ""; showJoin = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(.body, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.brand, in: Circle())
        }
        .accessibilityLabel("Ajouter")
    }

    /// Mes amis en rangée (bulles : défi en attente, score entre nous), ou la grande carte d'invitation.
    @ViewBuilder private var friendsHeader: some View {
        if let friends = overview?.friends {
            if friends.isEmpty {
                InviteFriendsCard(code: referral?.code ?? app.profile?.referralCode,
                                  onAdd: { showSearch = true }, onLinkDuel: { showLinkDuel = true })
            } else {
                FriendsStrip(friends: friends, duels: duels, onAdd: { showSearch = true },
                             onFriend: { path.append(.friend($0.id, $0.handle)) })
            }
        }
    }

    /// « Entre amis » et, à droite, le lien discret vers l'historique de tous les duels entre amis.
    private var friendsTitle: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Entre amis").font(.cfHeadline)
            Spacer()
            if !app.isAnonymous {
                NavigationLink(value: Route.duelHistory) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Historique")
                        Image(systemName: "chevron.right").font(.caption2.weight(.heavy))
                    }
                    .font(.system(.footnote, design: .rounded).weight(.black))
                    .foregroundStyle(Color.brand)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.row)
            }
        }
        .padding(.top, Space.s)
    }

    /// Ce qui attend le joueur. Absent s'il n'y a rien.
    @ViewBuilder private var toPlay: some View {
        let incoming = overview?.incoming ?? []
        if !incoming.isEmpty || !waitingDuels.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("À toi de jouer").labelCaps()
                ForEach(incoming) { request in
                    // Deux boutons de même taille, bien séparés : refuser ne se fait pas par erreur.
                    VStack(alignment: .leading, spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.handle).font(.cfTitle3)
                            Text("veut être ton ami").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        }
                        HStack(spacing: Space.m) {
                            Button { respond(request, accept: false) } label: {
                                Text("Refuser").frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(SmallPillStyle(fill: Color.paper, text: Color.inkSoft))
                            Button { respond(request, accept: true) } label: {
                                Text("Accepter").frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(SmallPillStyle(fill: Color.brand, text: .white))
                        }
                    }
                    .popCard(padding: 14)
                }
                ForEach(waitingDuels) { duel in
                    DuelRow(duel: duel, onOpen: { activeDuel = DuelLaunch(id: duel.id) },
                            onDecline: { Task { try? await app.service.duelDecline(duel.id); await load() } })
                }
            }
        }
    }

    private func respond(_ request: FriendRequest, accept: Bool) {
        Task {
            try? await app.service.respondFriend(friendship: request.friendshipId, accept: accept)
            if accept { Haptics.success() }
            await load()
        }
    }

    @ViewBuilder private var leaguesBlock: some View {
        if leagues.isEmpty {
            Button { showNewLeague = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill").font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(hex: 0xE8A400))
                        .frame(width: 34, height: 34).background(Color.sun.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Crée une ligue entre amis").font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                        Text("Un quiz privé chaque jour, un podium").font(.cfFootnote).foregroundStyle(Color.inkSoft).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(Color.inkSoft)
                }
                .popCard(padding: 12, radius: 18)
            }
            .buttonStyle(.row)
        } else {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Mes ligues").labelCaps()
                ForEach(leagues) { league in
                    NavigationLink(value: Route.league(league.id)) {
                        LeagueRow(league: league)
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }
}

/// Rappel discret : les fonctions sociales demandent un compte.
struct AccountNudge: View {
    @State private var showAccount = false

    var body: some View {
        Button { showAccount = true } label: {
            HStack(alignment: .top, spacing: Space.m) {
                Image(systemName: "person.crop.circle.badge.plus").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crée ton compte").font(.cfTitle3)
                    Text("Pour garder ta progression et apparaître chez tes amis.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer()
            }
            .foregroundStyle(Color.ink)
            .padding(Space.m)
            .background(Color.sun.opacity(0.45), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAccount) {
            AccountSheet()
        }
    }
}

/// Petit bouton pilule (accepter / refuser) : même taille pour les deux choix.
struct SmallPillStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .foregroundStyle(text)
            .padding(.horizontal, 14)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Récompense de la semaine à montrer (identifiée par sa semaine).
private struct ArenaRewardItem: Identifiable {
    let reward: ArenaWeekReward
    var id: String { reward.week }
}

/// Un duel classé touché dans « Mes duels » : son bilan (résultat ou « en jeu »).
private struct ArenaDuelDetail: View {
    let duel: ArenaDuel
    let onNext: () -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var result: ArenaDuelResult?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let result {
                ArenaResultView(result: result, me: app.profile?.handle ?? "Toi", onNext: onNext, onClose: { dismiss() })
            } else {
                ArenaPalette.night.ignoresSafeArea()
                if failed {
                    VStack(spacing: Space.m) {
                        Text("Bilan indisponible.").font(.cfHeadline).foregroundStyle(.white)
                        Button("Fermer") { dismiss() }.buttonStyle(.sun)
                    }
                    .padding(Space.gutter)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .task {
            do { result = try await app.service.arenaResult(duel.id) } catch { failed = true }
        }
    }
}
