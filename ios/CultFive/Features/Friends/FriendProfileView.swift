import SwiftUI
import CultFiveCore

/// Profil d'un ami : son 5 du jour, un gros bouton Duel, notre face-à-face et nos derniers duels.
/// Retirer ou bloquer passe par le menu « ⋯ ».
struct FriendProfileView: View {
    let friendId: UUID
    let handle: String

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var profile: FriendProfile?
    @State private var error: String?
    @State private var showSetup = false
    /// Duel créé dans la feuille de réglages : ouvert une fois la feuille refermée.
    @State private var pendingLaunch: DuelLaunch?
    @State private var activeDuel: DuelLaunch?
    @State private var confirmRemove = false
    @State private var confirmBlock = false
    @State private var report: ReportTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                if let profile {
                    todayCard(profile)
                    Button { showSetup = true } label: {
                        Label("Défier \(handle)", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ink)
                    headToHead(profile)
                    if !profile.duels.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Derniers duels").labelCaps()
                            ForEach(profile.duels) { duel in
                                DuelRow(duel: duel, showsDate: true, onOpen: { activeDuel = DuelLaunch(id: duel.id) })
                            }
                        }
                    }
                } else if let error {
                    RetryMessage(text: error) { Task { await load() } }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Space.xl)
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
                Menu {
                    Button("Retirer des amis", systemImage: "person.badge.minus") { confirmRemove = true }
                    Button("Signaler", systemImage: "flag") { report = ReportTarget(kind: .user, targetId: friendId, name: handle) }
                    Button("Bloquer", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.body.weight(.bold))
                }
                .accessibilityLabel("Options")
            }
        }
        .confirmationDialog("Retirer \(handle) de tes amis ?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Retirer", role: .destructive) {
                Task {
                    do {
                        try await app.service.removeFriend(friendId)
                        dismiss()
                    } catch {
                        app.show("Impossible de retirer cet ami. Réessaie.")
                    }
                }
            }
        }
        .confirmationDialog("Bloquer \(handle) ?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Bloquer", role: .destructive) {
                Task {
                    do {
                        try await app.service.blockUser(friendId)
                        dismiss()
                    } catch {
                        app.show("Impossible de bloquer ce joueur. Réessaie.")
                    }
                }
            }
        } message: {
            Text("Vous ne serez plus amis et \(handle) ne pourra plus te retrouver.")
        }
        .sheet(isPresented: $showSetup, onDismiss: {
            if let launch = pendingLaunch {
                pendingLaunch = nil
                activeDuel = launch
            }
        }) {
            DuelSetupSheet(opponentName: handle, friendId: friendId) { duel in
                pendingLaunch = DuelLaunch(id: duel.id)
                showSetup = false
                app.askNotificationsAfterSocial()
            }
        }
        .sheet(item: $report) { ContentReportSheet(target: $0) }
        .fullScreenCover(item: $activeDuel, onDismiss: { Task { await load() } }) { launch in
            DuelSessionView(duelId: launch.id)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            profile = try await app.service.friendProfile(friendId)
            error = nil
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Profil indisponible."
        }
    }

    // MARK: Blocs

    private var header: some View {
        HStack(alignment: .center, spacing: Space.m) {
            Leon(color: .brand, pose: .wave).frame(width: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(handle).font(.cfDisplay).lineLimit(1).minimumScaleFactor(0.6)
                if let profile {
                    HStack(spacing: Space.s) {
                        if profile.streak > 0 {
                            Label("\(profile.streak) j", systemImage: "flame.fill").foregroundStyle(Color(hex: 0xF76707))
                        }
                        Text("Niveau \(XPLevel(totalXP: profile.xpTotal).level)").foregroundStyle(Color.inkSoft)
                        if let cote = profile.cote {
                            Text("Elo \(CoteCULT.format(cote))\(profile.cotePlaced ? "" : " (prov.)")")
                                .foregroundStyle(profile.cotePlaced ? Color.ink : Color.inkSoft)
                        }
                    }
                    .font(.cfFootnote.weight(.bold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Space.m)
        .accessibilityElement(children: .combine)
    }

    private func todayCard(_ profile: FriendProfile) -> some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Son \(Brand.dailyName)").labelCaps()
                if let today = profile.today {
                    Text("\(today.score ?? 0)/5 aujourd'hui").font(.cfTitle3)
                    if let ms = today.totalMs {
                        Text("en \(DurationFormat.clock(milliseconds: ms))").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                } else {
                    Text("Pas encore joué aujourd'hui").font(.cfTitle3).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
            if let answers = profile.today?.answers {
                TallyMark(results: answers).frame(width: 46)
            }
        }
        .popCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func headToHead(_ profile: FriendProfile) -> some View {
        let h = profile.headToHead
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Face-à-face").labelCaps()
            if h.played == 0 {
                Text("Pas encore de duel terminé entre vous. Lance le premier !")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
            } else {
                HStack(alignment: .center) {
                    score("Toi", h.wins, highlight: h.wins > h.losses)
                    Text("–").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Color.inkSoft)
                    score(handle, h.losses, highlight: h.losses > h.wins)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    line("Duels terminés", "\(h.played)" + (h.draws > 0 ? " dont \(h.draws) égalité\(h.draws > 1 ? "s" : "")" : ""))
                    if let streak = h.streak, streak.count >= 2 {
                        line("Série en cours", streak.who == "me" ? "\(streak.count) victoires pour toi"
                                                                  : "\(streak.count) victoires pour \(handle)")
                    }
                    if let mine = h.myRate, let theirs = h.theirRate {
                        line("Bonnes réponses", "toi \(mine) % · \(handle) \(theirs) %")
                    }
                    if let best = h.myBest {
                        line("Ton record", "\(best.score)/\(best.total)")
                    }
                    line("Questions jouées", "\(h.questions)")
                }
            }
        }
        .popCard(padding: 16)
    }

    private func score(_ name: String, _ value: Int, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").numeral(size: 52).foregroundStyle(highlight ? Color.brand : Color.ink)
            Text(name).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.inkSoft)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(Color.ink).multilineTextAlignment(.trailing)
        }
        .font(.cfCallout)
    }
}

/// Réglages d'un duel : nombre de questions, domaines, difficulté.
struct DuelSetupSheet: View {
    /// Nom affiché (« Duel contre Théo ») ; `friendId` nil : défi par lien.
    let opponentName: String?
    let friendId: UUID?
    var onCreated: (Duel) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var settings = DuelSettings()
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text(opponentName.map { "Duel contre \($0)" } ?? "Défi par lien").font(.cfDisplay)
                    Text("Les mêmes questions pour vous deux, chacun à son rythme pendant 48 h. Sans effet sur l'Elo.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    option("Nombre de questions") {
                        ForEach(DuelSettings.counts, id: \.self) { n in
                            chip("\(n)", on: settings.count == n) { settings.count = n }
                        }
                    }
                    option("Domaines") {
                        chip("Tous", on: selected.isEmpty) { selected = [] }
                        ForEach(app.domains, id: \.id) { domain in
                            chip(domain.name, on: selected.contains(domain.id)) {
                                if selected.contains(domain.id) { selected.remove(domain.id) } else { selected.insert(domain.id) }
                            }
                        }
                    }
                    option("Difficulté") {
                        ForEach(DuelDifficulty.allCases, id: \.self) { level in
                            chip(level.title, on: settings.difficulty == level) { settings.difficulty = level }
                        }
                    }
                    if settings.difficulty == .auto {
                        Text("Auto : calée sur vos deux niveaux, pour un duel serré.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                }
                .padding(Space.gutter)
            }
            .safeAreaInset(edge: .bottom) {
                Button { create() } label: {
                    HStack(spacing: 8) {
                        if busy { ProgressView().controlSize(.small).tint(.white) }
                        Label("Lancer le duel", systemImage: "bolt.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.ink)
                .disabled(busy)
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.s)
                .background(Color.paper)
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func option<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps()
            FlowLayout(spacing: Space.s) { chips() }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.bounce) { action() }
        } label: {
            Text(title)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(on ? Color.white : Color.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(on ? Color.brand : Color.paperRaised, in: Capsule())
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func create() {
        busy = true
        error = nil
        settings.domains = app.domains.map(\.id).filter { selected.contains($0) }
        Task {
            do {
                let duel = try await app.service.duelCreate(friend: friendId, settings: settings)
                Haptics.soft()
                onCreated(duel)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Impossible de créer le duel."
            }
            busy = false
        }
    }
}
