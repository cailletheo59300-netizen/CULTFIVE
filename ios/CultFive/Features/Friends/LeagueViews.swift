import SwiftUI
import CultFiveCore

/// Recherche par pseudo (3 caractères min., préfixe) et demande d'ami.
struct AddFriendSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [HandleSearchResult] = []
    @State private var sent: Set<UUID> = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if query.count < 3 {
                    Text("Tape au moins 3 lettres du pseudo.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .listRowBackground(Color.paper)
                }
                ForEach(results) { result in
                    HStack {
                        Text(result.handle).font(.cfTitle3)
                        Spacer()
                        switch (result.relation, sent.contains(result.id)) {
                        case ("accepted", _):
                            Text("ami").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        case ("pending", _), (_, true):
                            Text(result.incoming == true ? "t'a invité" : "demande envoyée").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        default:
                            Button("Ajouter") { request(result) }.buttonStyle(.textLink)
                        }
                    }
                    .listRowBackground(Color.paper)
                }
                if let error {
                    Text(error).font(.cfFootnote).foregroundStyle(Color.wrong).listRowBackground(Color.paper)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Pseudo")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Ajouter un ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
            .task(id: query) {
                guard query.count >= 3 else { results = []; return }
                try? await Task.sleep(nanoseconds: 250_000_000)  // anti-rebond
                guard !Task.isCancelled else { return }
                results = (try? await app.service.searchHandles(query)) ?? []
            }
        }
    }

    private func request(_ result: HandleSearchResult) {
        Task {
            do {
                _ = try await app.service.requestFriend(handle: result.handle)
                sent.insert(result.id)
                Haptics.success()
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription
            }
        }
    }
}

struct NewLeagueSheet: View {
    var onCreated: (LeagueStandings) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var period: LeaguePeriod = .week
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Nouvelle ligue").font(.cfDisplay)
                TextField("Nom de la ligue", text: $name)
                    .font(.cfTitle3)
                    .padding(.vertical, Space.s)
                    .overlay(alignment: .bottom) { Hairline(color: .ink) }
                Picker("Période", selection: $period) {
                    Text("Semaine").tag(LeaguePeriod.week)
                    Text("Mois").tag(LeaguePeriod.month)
                }
                .pickerStyle(.segmented)
                Text("Les points : la somme de vos scores au \(Brand.dailyName). Égalité : le temps total départage.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                Spacer()
                Button("Créer la ligue") { create() }
                    .buttonStyle(.ink)
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 3 || busy)
            }
            .padding(Space.gutter)
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }

    private func create() {
        busy = true
        Task {
            do {
                let standings = try await app.service.createLeague(name: name, period: period)
                onCreated(standings)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Création impossible."
            }
            busy = false
        }
    }
}

/// Classement d'une ligue : somme des scores du 5 du jour sur la période.
struct LeagueView: View {
    let leagueId: UUID

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var standings: LeagueStandings?
    @State private var offset = 0
    @State private var confirmLeave = false
    @State private var showRules = false
    /// L'explication s'ouvre toute seule la première fois qu'on entre dans une ligue.
    @AppStorage("leagueRulesSeen") private var rulesSeen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let standings {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(standings.period == .week ? "Ligue · semaine" : "Ligue · mois").labelCaps()
                        Text(standings.name).font(.cfDisplay)
                        Text(periodLine(standings))
                            .font(.cfFootnote.weight(.semibold)).foregroundStyle(Color.inkSoft)
                    }
                    podiumCard(standings)
                    Picker("Période", selection: $offset) {
                        Text("En cours").tag(0)
                        Text("Précédente").tag(-1)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 8) {
                        ForEach(standings.standings) { row in
                            HStack(spacing: Space.m) {
                                Text("\(row.rank)")
                                    .font(.system(.headline, design: .rounded).weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(row.rank <= 3 && row.points > 0 ? Color.inkFixed : Color.inkSoft)
                                    .frame(width: 36, height: 36)
                                    .background(medal(row.rank, points: row.points), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.handle).font(.cfTitle3).fontWeight(row.isMe ? .bold : .semibold)
                                    Text("\(row.days) jour\(row.days > 1 ? "s" : "") · \(DurationFormat.clock(milliseconds: row.totalMs))")
                                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                }
                                Spacer()
                                if let tier = podiumTier(row, in: standings) {
                                    ChestView(tier: tier, open: offset < 0).frame(width: 30)
                                        .accessibilityLabel("Podium : \(tier.title.lowercased())")
                                }
                                Text("\(row.points)").font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                            }
                            .padding(12)
                            .background(row.isMe ? Color.brand.opacity(0.12) : Color.paperRaised,
                                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .strokeBorder(row.isMe ? Color.brand : .clear, lineWidth: 2))
                            .accessibilityElement(children: .combine)
                        }
                    }

                    ShareLink(item: Brand.leagueURL(code: standings.inviteCode),
                              message: Text("Rejoins ma ligue « \(standings.name) » sur \(Brand.name). Code : \(standings.inviteCode)")) {
                        HStack {
                            Text("Inviter dans la ligue")
                            Spacer()
                            Text(standings.inviteCode).font(.system(.callout, design: .monospaced)).opacity(0.7)
                        }
                    }
                    .buttonStyle(.ink)

                    Button("Quitter la ligue", role: .destructive) { confirmLeave = true }
                        .buttonStyle(TextLinkStyle(color: .wrong))
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Space.xxl)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .clearsTabBar()
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showRules = true } label: {
                    Image(systemName: "questionmark.circle").font(.body.weight(.bold))
                }
                .accessibilityLabel("Comment marchent les ligues")
            }
        }
        .sheet(isPresented: $showRules) { LeagueRulesSheet() }
        .onAppear {
            if !rulesSeen {
                rulesSeen = true
                showRules = true
            }
        }
        .task(id: offset) {
            standings = try? await app.service.leagueStandings(leagueId, offset: offset)
        }
        .confirmationDialog("Quitter cette ligue ?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) {
                Task {
                    try? await app.service.leaveLeague(leagueId)
                    dismiss()
                }
            }
        }
    }
}

extension LeagueView {
    /// « Se termine dimanche soir · dans 3 j » (en cours) ou « Du lundi 1er au dimanche 7 mars » (précédente).
    fileprivate func periodLine(_ standings: LeagueStandings) -> String {
        guard offset == 0 else { return "Du \(DateText.long(standings.startDate)) au \(DateText.long(standings.endDate))" }
        let end = DateText.long(standings.endDate)
        let days = DailyHomeView.daysLeft(until: standings.endDate) ?? 0
        let left = days <= 0 ? "dernier jour" : days == 1 ? "demain" : "dans \(days) jours"
        return "Se termine \(end) à minuit · \(left)"
    }

    /// Coffre du podium pour une ligne (seulement si la ligue compte assez de joueurs actifs et le joueur assez de jours).
    fileprivate func podiumTier(_ row: LeagueStandings.Row, in standings: LeagueStandings) -> ChestTier? {
        guard let podium = standings.podium, podium.activePlayers >= podium.minPlayers, row.days >= podium.minDays else { return nil }
        let eligible = standings.standings.filter { $0.days >= podium.minDays }
        guard let place = eligible.firstIndex(where: { $0.id == row.id }), place < 3 else { return nil }
        return [ChestTier.gold, .silver, .wood][place]
    }

    @ViewBuilder
    fileprivate func podiumCard(_ standings: LeagueStandings) -> some View {
        if let reward = standings.myReward {
            let waiting = app.progression?.chests.contains { $0.source == "league" } ?? false
            HStack(spacing: Space.m) {
                ChestView(tier: reward.tier, open: !waiting).frame(width: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu as fini \(reward.place == 1 ? "1er" : "\(reward.place)e") !").font(.cfTitle3)
                    Text("\(reward.tier.title) gagné.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 0)
                if waiting {
                    Button("Ouvrir") { app.openChests() }
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color(hex: 0x1E1340))
                        .padding(.horizontal, 14).frame(minHeight: 40)
                        .background(Color.sun, in: Capsule())
                }
            }
            .popCard(padding: 14)
        } else if offset == 0, let podium = standings.podium {
            HStack(spacing: Space.m) {
                HStack(alignment: .bottom, spacing: 2) {
                    ChestView(tier: .silver).frame(width: 28)
                    ChestView(tier: .gold).frame(width: 36)
                    ChestView(tier: .wood).frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if podium.activePlayers < podium.minPlayers {
                        let missing = podium.minPlayers - podium.activePlayers
                        Text("Encore \(missing) joueur\(missing > 1 ? "s" : "") actif\(missing > 1 ? "s" : "")")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("Il faut \(podium.minPlayers) joueurs qui font leur \(Brand.dailyName) pour que le podium gagne des coffres.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Le podium gagne un coffre").font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("Or, argent et bois pour les 3 premiers ayant joué au moins \(podium.minDays) jours.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .popCard(padding: 14)
            .onTapGesture { showRules = true }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Comment marchent les ligues, en 4 étapes illustrées.
struct LeagueRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Les ligues").font(.cfDisplay).padding(.top, Space.l)
                Text("Un classement privé entre amis, remis à zéro à chaque période.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                step(1, "Crée ou rejoins une ligue", "Partage son code à tes amis : seuls ceux qui l'ont peuvent entrer.") {
                    Text("K7P2QX")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                step(2, "Fais ton \(Brand.dailyName)", "Chaque bonne réponse vaut 1 point. À égalité, le plus rapide passe devant.") {
                    TallyMark(strokes: [.correct, .correct, .wrong, .correct, .correct]).frame(width: 60)
                }
                step(3, "La période se termine", "Chaque dimanche à minuit pour une ligue de la semaine, ou le dernier jour du mois.") {
                    VStack(spacing: 0) {
                        Text("DIM.").font(.system(.caption2, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 3).background(Color.wrong)
                        Text("23:59").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(Color.ink).padding(.vertical, 6)
                    }
                    .frame(width: 64)
                    .background(Color.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.hairline))
                }
                step(4, "Le podium gagne un coffre", "Or pour le 1er, argent pour le 2e, bois pour le 3e. Il faut au moins 4 joueurs actifs dans la ligue, et avoir joué au moins 3 jours (10 pour un mois).") {
                    HStack(alignment: .bottom, spacing: 2) {
                        podiumStep(.silver, height: 16)
                        podiumStep(.gold, height: 26)
                        podiumStep(.wood, height: 10)
                    }
                }
                Button("C'est compris") { dismiss() }.buttonStyle(.ink).padding(.top, Space.s)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .background(Color.paper)
        .presentationDragIndicator(.visible)
    }

    private func step<Art: View>(_ number: Int, _ title: String, _ detail: String, @ViewBuilder art: () -> Art) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            art().frame(width: 76, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(number). \(title)").font(.cfTitle3).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func podiumStep(_ tier: ChestTier, height: CGFloat) -> some View {
        VStack(spacing: 1) {
            ChestView(tier: tier).frame(width: 22)
            Rectangle().fill(Color.brand.opacity(0.25)).frame(width: 22, height: height)
        }
    }
}

/// Or, argent, bronze pour le podium ; neutre ensuite.
private func medal(_ rank: Int, points: Int) -> Color {
    guard points > 0 else { return .hairline }
    switch rank {
    case 1: return .sun
    case 2: return Color(hex: 0xD9DCE8)
    case 3: return Color(hex: 0xF2B489)
    default: return .hairline
    }
}
