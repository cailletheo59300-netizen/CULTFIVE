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
    /// Mon 5 du jour (score et temps) pour me placer dans le classement des amis.
    @State private var myToday: DailyResult?

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
                            Text("Amis").font(.cfDisplay)
                            Spacer()
                            TourButton(id: .friends)
                            addMenu
                        }
                        Text("Défie tes amis en duel : mêmes questions, chacun son tour.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
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
            .guidedTour(.friends)
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
        async let today: DailyResult? = app.daily?.state == .done ? (try? service.dailyResult(date: nil)) : nil
        duels = await myDuels ?? []
        myToday = await today
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

    /// Amis classés sur le 5 du jour (D-074) : ceux qui l'ont fait par score puis temps, toi compris ; ceux qui ne
    /// l'ont pas encore fait en bas, grisés. Un ami se touche : son profil (duel, face-à-face).
    @ViewBuilder private var friendsList: some View {
        let friends = overview?.friends ?? []
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mes amis").labelCaps()
                Spacer()
                if !friends.isEmpty {
                    Text("Classement du 5 du jour").font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            if friends.isEmpty {
                HStack(alignment: .center, spacing: Space.m) {
                    Leon(color: .brand, pose: .curious).frame(width: 90)
                    Text("Ajoute un ami avec le bouton +, puis défie-le en duel. Tu peux aussi défier n'importe qui avec un lien (+ → Défier par lien).")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Space.s)
            } else {
                let entries = rankedEntries(friends)
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        if let friend = entry.friend {
                            NavigationLink(value: Route.friend(friend.id, friend.handle)) {
                                FriendRankRow(entry: entry)
                            }
                            .buttonStyle(.row)
                        } else {
                            FriendRankRow(entry: entry)
                        }
                    }
                }
            }
            if let outgoing = overview?.outgoing, !outgoing.isEmpty {
                Text("En attente : " + outgoing.map(\.handle).joined(separator: ", "))
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
    }

    private func rankedEntries(_ friends: [Friend]) -> [FriendRankEntry] {
        var played: [FriendRankEntry] = friends.compactMap { friend in
            guard let today = friend.today, let score = today.score else { return nil }
            return FriendRankEntry(id: friend.id.uuidString, friend: friend, handle: friend.handle, score: score,
                                   totalMs: today.totalMs, streak: friend.streak, me: false)
        }
        if let mine = myToday {
            played.append(FriendRankEntry(id: "moi", friend: nil, handle: "Toi", score: mine.score, totalMs: mine.totalMs,
                                          streak: mine.streak, me: true))
        }
        played.sort { a, b in
            a.score != b.score ? a.score > b.score : (a.totalMs ?? .max) < (b.totalMs ?? .max)
        }
        for index in played.indices { played[index].rank = index + 1 }
        let waiting = friends.filter { $0.today?.score == nil }
            .map { FriendRankEntry(id: $0.id.uuidString, friend: $0, handle: $0.handle, score: nil, totalMs: nil,
                                   streak: $0.streak, me: false) }
        return played + waiting
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
/// Une place du classement des amis.
private struct FriendRankEntry: Identifiable {
    let id: String
    let friend: Friend?
    let handle: String
    let score: Int?
    let totalMs: Int?
    let streak: Int
    let me: Bool
    var rank: Int?

    init(id: String, friend: Friend?, handle: String, score: Int?, totalMs: Int?, streak: Int, me: Bool) {
        self.id = id
        self.friend = friend
        self.handle = handle
        self.score = score
        self.totalMs = totalMs
        self.streak = streak
        self.me = me
    }
}

/// Ligne du classement : rang (médaille sur le podium), pseudo et série, score et temps ; « pas encore joué » grisé.
private struct FriendRankRow: View {
    let entry: FriendRankEntry

    private static let medals: [Int: Color] = [1: Color(hex: 0xF2B705), 2: Color(hex: 0xADB5BD), 3: Color(hex: 0xCD7F32)]

    var body: some View {
        let played = entry.score != nil
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(entry.rank.flatMap { Self.medals[$0] } ?? Color.hairline)
                Text(entry.rank.map(String.init) ?? "–")
                    .font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(entry.rank.flatMap { Self.medals[$0] } != nil ? Color.white : Color.inkSoft)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.handle).font(.system(.callout, design: .rounded).weight(.black))
                    .foregroundStyle(played ? Color.ink : Color.inkSoft).lineLimit(1)
                if entry.streak > 0 {
                    Label("\(entry.streak)", systemImage: "flame.fill")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color(hex: 0xE8452C).opacity(played ? 1 : 0.5))
                }
            }
            Spacer(minLength: 4)
            if let score = entry.score {
                if let totalMs = entry.totalMs {
                    Text(DurationFormat.clock(milliseconds: totalMs))
                        .font(.system(.caption, design: .rounded).weight(.bold)).monospacedDigit()
                        .foregroundStyle(Color.inkSoft)
                }
                Text("\(score)/5").font(.cfNumber).foregroundStyle(Color.ink)
            } else {
                Text("pas encore joué").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            if entry.friend != nil {
                Image(systemName: "chevron.right").font(.caption.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(entry.me ? Color.sun.opacity(0.35) : Color.paperRaised,
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .opacity(played ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.friend != nil ? "Ouvre son profil" : "")
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
