import SwiftUI
import CultFiveCore

/// Amis : court et clair. En haut, seulement ce qui attend le joueur (demandes, duels à jouer) ; puis ses ligues et ses
/// amis en listes simples. Toutes les actions sur un ami (duel, face-à-face, retirer) sont dans son profil ; les
/// actions globales (ajouter, défier par lien, ligues) dans le bouton « + ».
struct FriendsView: View {
    enum Route: Hashable {
        case league(UUID)
        case friend(UUID, String)
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

    /// Duels qui attendent le joueur, ou un adversaire par lien.
    private var waitingDuels: [Duel] {
        duels.filter { $0.myTurn || ($0.status == "open" && $0.opponent == nil) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Amis").font(.cfDisplay)
                        Spacer()
                        addMenu
                    }
                    .padding(.top, Space.l)

                    if app.isAnonymous {
                        AccountNudge()
                    }
                    toPlay
                    leaguesBlock
                    friendsList
                    invite
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
            .clearsTabBar()
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load() }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .league(let id): LeagueView(leagueId: id)
                case .friend(let id, let handle): FriendProfileView(friendId: id, handle: handle)
                }
            }
        }
        .sheet(isPresented: $showSearch, onDismiss: { Task { await load() } }) {
            AddFriendSheet()
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
                    app.show((error as? LocalizedError)?.errorDescription ?? "Ce défi n'est plus disponible.")
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
        duels = await myDuels ?? []
        overview = await friends
        leagues = await mine ?? []
        referral = await referralInfo
    }


    // MARK: Blocs

    private var addMenu: some View {
        Menu {
            Button("Ajouter un ami", systemImage: "person.badge.plus") { showSearch = true }
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

    /// Ce qui attend le joueur. Absent s'il n'y a rien.
    @ViewBuilder private var toPlay: some View {
        let incoming = overview?.incoming ?? []
        if !incoming.isEmpty || !waitingDuels.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("À toi de jouer").labelCaps()
                ForEach(incoming) { request in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.handle).font(.cfTitle3)
                            Text("veut être ton ami").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        Button("Refuser") { respond(request, accept: false) }.buttonStyle(.textLink)
                        Button("Accepter") { respond(request, accept: true) }
                            .buttonStyle(InkButtonStyle(arrow: false))
                            .fixedSize()
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

    @ViewBuilder private var friendsList: some View {
        let friends = overview?.friends ?? []
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Mes amis").labelCaps()
            if friends.isEmpty {
                HStack(alignment: .center, spacing: Space.m) {
                    Leon(color: .brand, pose: .curious).frame(width: 90)
                    Text("Personne pour l'instant. Invite quelqu'un qui aime avoir raison.")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
                .padding(.vertical, Space.s)
            } else {
                ForEach(friends) { friend in
                    NavigationLink(value: Route.friend(friend.id, friend.handle)) {
                        FriendRow(friend: friend)
                    }
                    .buttonStyle(.row)
                }
            }
            if let outgoing = overview?.outgoing, !outgoing.isEmpty {
                Text("En attente : " + outgoing.map(\.handle).joined(separator: ", "))
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
    }

    @ViewBuilder private var leaguesBlock: some View {
        if leagues.isEmpty {
            Button { showNewLeague = true } label: {
                EditorialRow(label: "Ligues", value: "Crée une ligue entre amis",
                             detail: "Un quiz privé chaque jour, un classement, un podium", symbol: "trophy.fill", chevron: true)
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

    @ViewBuilder private var invite: some View {
        if let code = referral?.code ?? app.profile?.referralCode {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Inviter").labelCaps()
                Text("Ton ami reçoit 100 \(Brand.currencyPlural) en créant son compte. Toi, 150 quand il termine son premier \(Brand.dailyName), et un bonus à 3, 5 et 10 amis.")
                    .font(.cfReading)
                    .fixedSize(horizontal: false, vertical: true)
                if let referral, referral.qualified > 0 {
                    Text("\(referral.qualified) ami\(referral.qualified > 1 ? "s" : "") déjà arrivé\(referral.qualified > 1 ? "s" : "") grâce à toi.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                ShareLink(item: Brand.inviteURL(code: code),
                          message: Text("Viens tester ta culture sur \(Brand.name). Et toi, tu sais quoi ?")) {
                    HStack {
                        Text("Partager mon lien")
                        Spacer()
                        Text(code).font(.system(.callout, design: .monospaced)).opacity(0.7)
                    }
                }
                .buttonStyle(.ink)
            }
        }
    }
}

/// Un ami dans la liste : pseudo, série, son 5 du jour. Toucher ouvre son profil.
private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.handle).font(.cfTitle3).foregroundStyle(Color.ink)
                Text(friend.streak > 0 ? "\(friend.streak) jour\(friend.streak > 1 ? "s" : "") de série" : "pas de série en cours")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if let today = friend.today, let answers = today.answers {
                HStack(spacing: Space.s) {
                    Text("\(today.score ?? 0)/5").font(.cfNumber).foregroundStyle(Color.ink)
                    TallyMark(results: answers).frame(width: 34)
                }
            } else {
                Text("pas encore joué").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
        }
        .popCard(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre son profil")
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
