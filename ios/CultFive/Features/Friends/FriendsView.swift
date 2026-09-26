import SwiftUI
import CultFiveCore

/// Amis : des personnes et leur 5 du jour, des ligues, une invitation. Favorise l'interaction, pas la contemplation.
struct FriendsView: View {
    @Environment(AppModel.self) private var app
    @State private var overview: FriendsOverview?
    @State private var leagues: [LeagueSummary] = []
    @State private var referral: ReferralOverview?
    @State private var showSearch = false
    @State private var showNewLeague = false
    @State private var joinCode = ""
    @State private var showJoin = false
    @State private var path: [UUID] = []
    @State private var error: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Amis").font(.cfDisplay)
                        Spacer()
                        Button { showSearch = true } label: {
                            Label("Ajouter", systemImage: "plus").font(.system(.callout).weight(.semibold))
                        }
                        .buttonStyle(.textLink)
                    }
                    .padding(.top, Space.l)

                    if app.isAnonymous {
                        AccountNudge()
                    }
                    requests
                    friendsList
                    leaguesBlock
                    invite
                    if let error {
                        Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load() }
            .navigationDestination(for: UUID.self) { id in
                LeagueView(leagueId: id)
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
                    path.append(standings.id)
                }
            }
        }
        .alert("Rejoindre une ligue", isPresented: $showJoin) {
            TextField("Code", text: $joinCode).textInputAutocapitalization(.characters)
            Button("Rejoindre") { Task { await join(code: joinCode) } }
            Button("Annuler", role: .cancel) {}
        }
        .task {
            await load()
            #if DEBUG
            if Demo.screen == .league, let first = leagues.first { path.append(first.id) }
            #endif
        }
        .task(id: app.pendingLeagueCode) {
            if let code = app.pendingLeagueCode {
                app.pendingLeagueCode = nil
                await join(code: code)
            }
        }
    }

    private func load() async {
        let service = app.service
        async let friends = try? service.friends()
        async let mine = try? service.leagues()
        async let referralInfo = try? service.referralOverview()
        overview = await friends
        leagues = await mine ?? []
        referral = await referralInfo
    }

    private func join(code: String) async {
        do {
            let standings = try await app.service.joinLeague(code: code)
            await load()
            path.append(standings.id)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
        }
    }

    // MARK: Blocs

    @ViewBuilder private var requests: some View {
        if let incoming = overview?.incoming, !incoming.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Demandes").labelCaps()
                ForEach(incoming) { request in
                    HStack {
                        Text(request.handle).font(.cfTitle3)
                        Spacer()
                        Button("Refuser") { respond(request, accept: false) }.buttonStyle(.textLink)
                        Button("Accepter") { respond(request, accept: true) }
                            .buttonStyle(InkButtonStyle(arrow: false))
                            .fixedSize()
                    }
                    .padding(.vertical, Space.s)
                    .overlay(alignment: .bottom) { Hairline() }
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
            Text("Le \(Brand.dailyName) de tes amis").labelCaps()
            if friends.isEmpty {
                HStack(alignment: .center, spacing: Space.m) {
                    Leon(color: .chloro, pose: .curious).frame(width: 90)
                    Text("Personne pour l'instant. Invite quelqu'un qui aime avoir raison.")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
                .padding(.vertical, Space.s)
            } else {
                ForEach(friends) { friend in
                    FriendRow(friend: friend) {
                        Task {
                            try? await app.service.removeFriend(friend.id)
                            await load()
                        }
                    } onBlock: {
                        Task {
                            try? await app.service.blockUser(friend.id)
                            await load()
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

    private var leaguesBlock: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Ligues privées").labelCaps()
                Spacer()
                Button("Rejoindre") { joinCode = ""; showJoin = true }.buttonStyle(.textLink)
                Button("Créer") { showNewLeague = true }.buttonStyle(.textLink)
            }
            if leagues.isEmpty {
                Text("Une ligue, c'est le 5 du jour entre amis, sur la semaine ou le mois.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
            }
            ForEach(leagues) { league in
                NavigationLink(value: league.id) {
                    EditorialRow(label: league.period == .week ? "Semaine" : "Mois", value: league.name,
                                 detail: "\(league.members) membre\(league.members > 1 ? "s" : "")", chevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    @ViewBuilder private var invite: some View {
        if let code = referral?.code ?? app.profile?.referralCode {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Inviter").labelCaps()
                Text("Ton ami reçoit 100 \(Brand.currencyPlural). Toi, 150 quand il termine son premier \(Brand.dailyName).")
                    .font(.cfBodySerif)
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

private struct FriendRow: View {
    let friend: Friend
    var onRemove: () -> Void
    var onBlock: () -> Void

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
                    Text("\(today.score ?? 0)/5").font(.cfNumber)
                    TallyMark(results: answers).frame(width: 34)
                }
            } else {
                Text("pas encore joué").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
        .padding(.vertical, Space.s)
        .overlay(alignment: .bottom) { Hairline() }
        .contextMenu {
            Button("Retirer des amis", systemImage: "person.badge.minus", action: onRemove)
            Button("Bloquer", systemImage: "hand.raised", role: .destructive, action: onBlock)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Maintiens pour retirer ou bloquer")
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
            .background(Color.chloro.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAccount) {
            AccountSheet()
        }
    }
}
