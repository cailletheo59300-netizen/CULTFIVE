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
    @State private var creating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                if let profile {
                    todayCard(profile)
                    VStack(spacing: 6) {
                        Button { quickDuel() } label: {
                            HStack(spacing: 8) {
                                if creating { ProgressView().controlSize(.small).tint(.white) }
                                Label("Défier \(handle)", systemImage: "bolt.fill")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ink)
                        .disabled(creating)
                        HStack(spacing: 4) {
                            Text("7 questions · 25 s")
                            Text("·")
                            Button("Plus de réglages") { showSetup = true }.foregroundStyle(Color.brand)
                        }
                        .font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                    }
                    HeadToHeadCard(me: app.profile?.handle ?? "Toi", friend: handle, friendAvatar: profile.avatar, h: profile.headToHead)
                    if !profile.duels.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Nos duels").labelCaps()
                                Spacer()
                                if profile.duels.count > 5 {
                                    NavigationLink {
                                        FriendDuelsPage(handle: handle, duels: profile.duels)
                                    } label: {
                                        Text("Voir plus ›").font(.system(.footnote, design: .rounded).weight(.black))
                                            .foregroundStyle(Color.brand)
                                    }
                                }
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(profile.duels.prefix(5).enumerated()), id: \.element.id) { index, duel in
                                    if index > 0 { Hairline().padding(.leading, 12) }
                                    Button { activeDuel = DuelLaunch(id: duel.id) } label: {
                                        DuelHistoryRow(duel: duel, showsOpponent: false)
                                    }
                                    .buttonStyle(.row)
                                }
                            }
                            .popCard(padding: 0, radius: 20)
                        }
                    }
                    if let showcase = profile.showcase, !showcase.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Sa vitrine").labelCaps()
                            ShowcaseStage(socle: showcase.socleStyle, slots: ShowcaseSlot.slots(of: showcase))
                                .padding(Space.m)
                                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Vitrine de \(handle)")
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

    /// Défi en un appui : format par défaut (7 questions, 25 s).
    private func quickDuel() {
        creating = true
        Task {
            do {
                let duel = try await app.service.duelCreate(friend: friendId, settings: DuelSettings())
                Haptics.soft()
                app.askNotificationsAfterSocial()
                activeDuel = DuelLaunch(id: duel.id)
            } catch {
                app.show(error, "Impossible de lancer le duel.")
            }
            creating = false
        }
    }

    private func load() async {
        do {
            profile = try await app.service.friendProfile(friendId)
            error = nil
        } catch {
            self.error = error.userMessage("Profil indisponible.")
        }
    }

    // MARK: Blocs

    private var header: some View {
        HStack(alignment: .center, spacing: Space.m) {
            ArenaAvatar(handle: handle, size: 76, avatar: profile?.avatar)
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
}

/// Réglages d'un duel : nombre de questions, domaines, difficulté.
struct DuelSetupSheet: View {
    /// Nom affiché (« Duel contre Théo ») ; `friendId` nil : défi par lien.
    let opponentName: String?
    let friendId: UUID?
    /// Réglages de départ (feuille « Contre un ami »).
    var initial: DuelSettings? = nil
    /// Si présent : on choisit seulement le format (bouton « Valider »), sans créer de duel.
    var onSettings: ((DuelSettings) -> Void)? = nil
    var onCreated: (Duel) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var settings = DuelSettings()
    @State private var selected: Set<String> = []
    @State private var started = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text(onSettings != nil ? "Réglages du duel" : opponentName.map { "Duel contre \($0)" } ?? "Défi par lien")
                        .font(.cfDisplay)
                    Text("Les mêmes questions pour vous deux, chacun quand il veut pendant 48 h. Sans effet sur l'Elo ni sur les points de la semaine.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    option("Nombre de questions") {
                        ForEach(DuelSettings.counts, id: \.self) { n in
                            chip("\(n)", on: settings.count == n) { settings.count = n }
                        }
                    }
                    Label(settings.count == DuelSettings.quickCount ? "25 s par question, comme à l'Arène." : "Sans chrono : prends ton temps.",
                          systemImage: settings.count == DuelSettings.quickCount ? "timer" : "hourglass")
                        .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
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
                        if onSettings != nil {
                            Label("Valider", systemImage: "checkmark")
                        } else {
                            Label("Lancer le duel", systemImage: "bolt.fill")
                        }
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
        .onAppear {
            guard !started, let initial else { return }
            started = true
            settings = initial
            selected = Set(initial.domains)
        }
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
        if let onSettings {
            busy = false
            onSettings(settings)
            return
        }
        Task {
            do {
                let duel = try await app.service.duelCreate(friend: friendId, settings: settings)
                Haptics.soft()
                onCreated(duel)
            } catch {
                self.error = error.userMessage("Impossible de créer le duel.")
            }
            busy = false
        }
    }
}
