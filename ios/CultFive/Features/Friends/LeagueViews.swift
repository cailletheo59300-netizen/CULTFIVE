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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let standings {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(standings.period == .week ? "Ligue · semaine" : "Ligue · mois").labelCaps()
                        Text(standings.name).font(.cfDisplay)
                        Text("Du \(DateText.long(standings.startDate)) au \(DateText.long(standings.endDate))")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Picker("Période", selection: $offset) {
                        Text("En cours").tag(0)
                        Text("Précédente").tag(-1)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        ForEach(standings.standings) { row in
                            HStack(spacing: Space.m) {
                                Text("\(row.rank)")
                                    .font(.system(.title2, design: .serif).weight(.bold))
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .leading)
                                    .foregroundStyle(row.rank == 1 && row.points > 0 ? Color.ink : Color.inkSoft)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.handle).font(.cfTitle3).fontWeight(row.isMe ? .bold : .semibold)
                                    Text("\(row.days) jour\(row.days > 1 ? "s" : "") · \(DurationFormat.clock(milliseconds: row.totalMs))")
                                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                }
                                Spacer()
                                Text("\(row.points)").font(.system(.title3, design: .serif).weight(.bold)).monospacedDigit()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, row.isMe ? Space.s : 0)
                            .background(row.isMe ? Color.chloro.opacity(0.4) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(alignment: .bottom) { Hairline() }
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
            .padding(.bottom, Space.xxl)
        }
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
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
