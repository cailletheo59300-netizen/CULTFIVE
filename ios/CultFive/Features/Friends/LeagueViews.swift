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
                self.error = error.userMessage
            }
        }
    }
}

// MARK: - Temps et réglages (textes)

/// Textes des ligues : temps restant, réglages. Les dates viennent du serveur (fuseau de la ligue).
enum LeagueText {
    static func duration(_ code: String) -> String {
        switch code {
        case "1w": return "1 semaine"
        case "2w": return "2 semaines"
        case "open": return "sans fin"
        default: return "1 mois"
        }
    }

    static func difficulty(_ code: String) -> String {
        (DuelDifficulty(rawValue: code) ?? .auto).title
    }

    /// « 10 questions/jour · tous les domaines · auto · 1 semaine »
    static func settings(_ s: LeagueSettings) -> String {
        let domains = s.domains ?? []
        let where_ = domains.isEmpty ? "tous les domaines"
            : domains.count <= 2 ? domains.map(DomainPalette.fallbackName).joined(separator: ", ") : "\(domains.count) domaines"
        if s.duration == "open" {
            return "\(s.questionCount) questions par quiz · \(where_) · \(difficulty(s.difficulty).lowercased()) · sans chrono"
        }
        return "\(s.questionCount) questions/jour · \(where_) · \(difficulty(s.difficulty).lowercased()) · \(duration(s.duration))"
    }

    /// « 6 jours restants », « Se termine demain soir », « Dernier jour : fin ce soir à minuit », « Commence demain »,
    /// « Terminée le mardi 9 mars ».
    static func remaining(status: String?, daysLeft: Int?, startsIn: Int?, endDate: String?, endsAt: String?, timezone: String?) -> String {
        switch status {
        case "upcoming":
            let n = startsIn ?? 1
            return n <= 1 ? "Commence demain" : "Commence dans \(n) jours"
        case "finished":
            return endDate.map { "Terminée le \(DateText.long($0))" } ?? "Terminée"
        default:
            guard let left = daysLeft else { return "" }
            switch left {
            case ..<1: return "Dernier jour : fin \(endTime(endsAt: endsAt, timezone: timezone))"
            case 1: return "Se termine demain soir"
            default: return "\(left) jours restants"
            }
        }
    }

    /// « ce soir à minuit » dans le fuseau de la ligue ; sinon l'heure de fin dans le fuseau de l'iPhone.
    private static func endTime(endsAt: String?, timezone: String?) -> String {
        guard let timezone, timezone != TimeZone.current.identifier, let raw = endsAt, let date = parse(raw) else {
            return "ce soir à minuit"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE HH'h'mm"
        return "\(formatter.string(from: date)) (ton heure)"
    }

    static func parse(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// Dates prévues à la création (même règle que le serveur) : « Du mer. 30 sept. au jeu. 29 oct. · 30 jours ».
    static func plannedRange(duration: String, startToday: Bool) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: startToday ? 0 : 1, to: today) else { return "" }
        let end: Date?
        switch duration {
        case "1w": end = calendar.date(byAdding: .day, value: 6, to: start)
        case "2w": end = calendar.date(byAdding: .day, value: 13, to: start)
        default: end = calendar.date(byAdding: .month, value: 1, to: start).flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
        }
        guard let end else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return "Du \(formatter.string(from: start)) au \(formatter.string(from: end)) inclus · \(days) jours"
    }
}

// MARK: - Création

struct NewLeagueSheet: View {
    var onCreated: (LeagueStandings) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LeagueDraft()
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("Nouvelle ligue").font(.cfDisplay)
                    TextField("Nom de la ligue", text: $draft.name)
                        .font(.cfTitle3)
                        .padding(.vertical, Space.s)
                        .overlay(alignment: .bottom) { Hairline(color: .ink) }
                    option("Format") {
                        chip("Ouverte", on: open) { draft.format = "open" }
                        chip("Quiz du jour", on: !open) { draft.format = "daily" }
                    }
                    Text(open ? "Des quiz identiques pour tous, à jouer quand on veut, sans chrono. Un classement général sur tous les quiz. Sans effet sur l'Elo."
                              : "Chaque jour, un quiz propre à la ligue, le même pour tous les membres, à faire avant minuit. Indépendant du \(Brand.dailyName) de Brainlix, sans effet sur l'Elo.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    option(open ? "Questions par quiz" : "Questions par jour") {
                        ForEach(LeagueSettings.counts, id: \.self) { n in
                            chip("\(n)", on: draft.settings.questionCount == n) { draft.settings.questionCount = n }
                        }
                    }
                    if open {
                        option("Quiz pour commencer") {
                            ForEach(LeagueDraft.quizChoices, id: \.self) { n in
                                chip("\(n)", on: draft.quizzes == n) { draft.quizzes = n }
                            }
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
                            chip(level.title, on: draft.settings.difficulty == level.rawValue) { draft.settings.difficulty = level.rawValue }
                        }
                    }
                    if open {
                        option("Fin") {
                            chip("Pas de fin", on: draft.days == nil) { draft.days = nil }
                            ForEach([7, 14, 30], id: \.self) { n in
                                chip(n == 30 ? "1 mois" : n == 14 ? "2 semaines" : "1 semaine", on: draft.days == n) { draft.days = n }
                            }
                        }
                    } else {
                        option("Durée") {
                            ForEach(["1w", "2w", "1m"], id: \.self) { code in
                                chip(LeagueText.duration(code), on: draft.settings.duration == code) { draft.settings.duration = code }
                            }
                        }
                        option("Début") {
                            chip("Aujourd'hui", on: draft.startToday) { draft.startToday = true }
                            chip("Demain", on: !draft.startToday) { draft.startToday = false }
                        }
                    }
                    option("Membres au maximum") {
                        ForEach(LeagueSettings.memberLimits, id: \.self) { n in
                            chip("\(n)", on: draft.settings.maxMembers == n) { draft.settings.maxMembers = n }
                        }
                    }
                    if open {
                        Text("Points : 1 par bonne réponse, sur tous les quiz. À égalité, le premier à avoir fini passe devant. Tu pourras ajouter des quiz et terminer la ligue quand tu veux.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label(LeagueText.plannedRange(duration: draft.settings.duration, startToday: draft.startToday), systemImage: "calendar")
                            .font(.cfCallout.weight(.semibold)).foregroundStyle(Color.ink)
                        Text("Points : 1 par bonne réponse. À égalité, le plus rapide passe devant. Un jour manqué compte 0.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Text("À la fin : podium (1er, 2e, 3e) et trophée « Vainqueur de ligue » pour le 1er, dès 3 joueurs.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                }
                .padding(Space.gutter)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Créer la ligue") { create() }
                    .buttonStyle(.ink)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).count < 3 || busy)
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.s)
                    .background(Color.paper)
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }

    private var open: Bool { draft.format == "open" }

    private func option<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps()
            FlowLayout(spacing: Space.s) { chips() }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        LeagueChip(title: title, on: on, action: action)
    }

    private func create() {
        busy = true
        error = nil
        draft.settings.domains = app.domains.map(\.id).filter { selected.contains($0) }
        Task {
            do {
                let standings = try await app.service.createLeague(draft)
                Haptics.success()
                onCreated(standings)
            } catch {
                self.error = error.userMessage("Création impossible.")
            }
            busy = false
        }
    }
}

struct LeagueChip: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
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
}

// MARK: - Rejoindre (aperçu)

/// Code de ligue à confirmer (lien ou saisie).
struct LeagueJoinRequest: Identifiable {
    let id = UUID()
    let code: String
}

/// Avant d'entrer : nom, créateur, membres, réglages, dates. Rien n'est rejoint sans « Rejoindre ».
struct LeagueJoinSheet: View {
    let code: String
    var onJoined: (LeagueStandings) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var preview: LeaguePreview?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if let preview, preview.found {
                Text("Rejoindre la ligue").labelCaps()
                Text(preview.name ?? "Ligue").font(.cfDisplay)
                VStack(alignment: .leading, spacing: 8) {
                    if let owner = preview.owner { Label("Créée par \(owner)", systemImage: "person.fill") }
                    Label("\(preview.members ?? 0) membre\((preview.members ?? 0) > 1 ? "s" : "") sur \(preview.maxMembers ?? 50)",
                          systemImage: "person.3.fill")
                    if preview.format == "open" {
                        Label("Ligue ouverte · \(preview.quizzes ?? 0) quiz à jouer quand tu veux", systemImage: "list.number")
                    }
                    if let settings = preview.settings { Label(LeagueText.settings(settings), systemImage: "slider.horizontal.3") }
                    if preview.openEnded != true {
                        Label(LeagueText.remaining(status: preview.status, daysLeft: preview.daysLeft, startsIn: nil,
                                                   endDate: preview.endsOn, endsAt: nil, timezone: nil), systemImage: "calendar")
                    }
                }
                .font(.cfCallout).foregroundStyle(Color.ink)
                if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                Spacer()
                Button(preview.isMember == true ? "Ouvrir la ligue" : "Rejoindre") { join() }
                    .buttonStyle(.ink)
                    .disabled(busy)
                Button("Annuler") { dismiss() }.buttonStyle(.textLink).frame(maxWidth: .infinity)
            } else if let preview, !preview.found {
                Spacer()
                Leon(pose: .curious).frame(width: 120)
                Text(preview.error == "rate_limited" ? "Trop d'essais de codes. Réessaie dans une heure."
                                                     : "Aucune ligue avec le code \(code.uppercased()). Vérifie-le auprès de ton ami.")
                    .font(.cfHeadline)
                Spacer()
                Button("Fermer") { dismiss() }.buttonStyle(.ink)
            } else if let error {
                Spacer()
                Text(error).font(.cfHeadline)
                Spacer()
                Button("Fermer") { dismiss() }.buttonStyle(.ink)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Space.gutter)
        .background(Color.paper)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            do { preview = try await app.service.leaguePreview(code: code) } catch {
                self.error = error.userMessage("Ligue introuvable.")
            }
        }
    }

    private func join() {
        busy = true
        Task {
            do {
                let standings = try await app.service.joinLeague(code: code)
                Haptics.success()
                onJoined(standings)
            } catch {
                self.error = error.userMessage("Impossible de rejoindre cette ligue.")
            }
            busy = false
        }
    }
}

// MARK: - Ligne dans la liste

struct LeagueRow: View {
    let league: LeagueSummary

    private var status: (String, Color) {
        if league.isOpen {
            switch (league.status, league.todayState) {
            case ("finished", _): return ("Terminée", .inkSoft)
            case (_, "todo"), (_, "in_progress"): return ("Un quiz t'attend", .brand)
            default: return ("Tous les quiz faits", .correct)
            }
        }
        switch league.todayState {
        case "todo": return ("Quiz du jour à jouer", .brand)
        case "in_progress": return ("Quiz du jour à finir", .brand)
        case "done": return ("Quiz du jour fait", .correct)
        default:
            return (LeagueText.remaining(status: league.status, daysLeft: league.daysLeft, startsIn: league.startsIn,
                                         endDate: nil, endsAt: nil, timezone: nil), .inkSoft)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(league.todayState == "todo" || league.todayState == "in_progress" ? Color.white : Color.sun)
                .frame(width: 42, height: 42)
                .background(league.todayState == "todo" || league.todayState == "in_progress" ? Color.brand : Color.sun.opacity(0.2),
                            in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(league.name).font(.cfTitle3).foregroundStyle(Color.ink)
                Text(status.0).font(.cfFootnote.weight(.bold)).foregroundStyle(status.1)
                if league.isOpen, league.status == "active" {
                    Text([league.myRank.map { $0 == 1 ? "1er" : "\($0)e" }, league.quizzes.map { "\($0) quiz" },
                          "\(league.members) membres"].compactMap { $0 }.joined(separator: " · "))
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                } else if league.status == "active", let left = league.daysLeft {
                    Text([league.myRank.map { $0 == 1 ? "1er" : "\($0)e" }, left == 0 ? "dernier jour" : "\(left) j restants",
                          "\(league.members) membres"].compactMap { $0 }.joined(separator: " · "))
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
        }
        .popCard(padding: 12)
    }
}

// MARK: - Page d'une ligue

/// Une ligue : temps restant, quiz du jour de la ligue, classement de la saison, réglages, membres, invitation.
struct LeagueView: View {
    let leagueId: UUID

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var standings: LeagueStandings?
    @State private var offset = 0
    @State private var confirmLeave = false
    @State private var confirmCode = false
    @State private var confirmSeason = false
    @State private var showRules = false
    @State private var playing = false
    @State private var showDay = false
    /// Ligue ouverte : quiz à jouer, scores d'un quiz, fin demandée par le créateur.
    @State private var playingQuiz: QuizPick?
    @State private var quizScores: QuizPick?
    @State private var confirmEnd = false
    @State private var busy = false
    @State private var kick: LeagueStandings.Row?
    @State private var report: ReportTarget?
    @State private var error: String?
    /// L'explication s'ouvre toute seule la première fois qu'on entre dans une ligue.
    @AppStorage("leagueRulesSeenV3") private var rulesSeen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let standings {
                    header(standings)
                    if standings.isOpen {
                        openQuizzes(standings)
                    } else if offset == 0 {
                        quizCard(standings)
                    }
                    podiumCard(standings)
                    if standings.hasPrevious == true {
                        Picker("Saison", selection: $offset) {
                            Text("Saison en cours").tag(0)
                            Text("Précédente").tag(-1)
                        }
                        .pickerStyle(.segmented)
                    }
                    ranking(standings)
                    settingsCard(standings)
                    invite(standings)
                    if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
                    Button("Quitter la ligue", role: .destructive) { confirmLeave = true }
                        .buttonStyle(TextLinkStyle(color: .wrong))
                } else if let error {
                    RetryMessage(text: error) { Task { await load() } }
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
                Menu {
                    Button("Comment marchent les ligues", systemImage: "questionmark.circle") { showRules = true }
                    if let standings, !standings.isOwner {
                        Button("Signaler la ligue", systemImage: "flag") {
                            report = ReportTarget(kind: .league, targetId: leagueId, name: standings.name)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.body.weight(.bold))
                }
                .accessibilityLabel("Options de la ligue")
            }
        }
        .sheet(isPresented: $showRules) { LeagueRulesSheet() }
        .sheet(isPresented: $showDay) { LeagueDaySheet(leagueId: leagueId) }
        .sheet(item: $report) { ContentReportSheet(target: $0) }
        .fullScreenCover(isPresented: $playing, onDismiss: { Task { await load() } }) {
            LeagueQuizView(leagueId: leagueId, name: standings?.name ?? "Ligue")
        }
        .fullScreenCover(item: $playingQuiz, onDismiss: { Task { await load() } }) { pick in
            LeagueQuizView(leagueId: leagueId, name: standings?.name ?? "Ligue", quiz: pick.n)
        }
        .sheet(item: $quizScores) { pick in LeagueDaySheet(leagueId: leagueId, quiz: pick.n) }
        .confirmationDialog("Terminer la ligue ?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Terminer maintenant", role: .destructive) { endLeague() }
        } message: {
            Text("Le classement devient définitif : podium et trophée « Vainqueur de ligue » pour le 1er (dès 3 joueurs). Plus personne ne pourra jouer.")
        }
        .onAppear {
            if !rulesSeen {
                rulesSeen = true
                showRules = true
            }
        }
        .task(id: offset) { await load() }
        .refreshable { await load() }
        .confirmationDialog("Quitter cette ligue ?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) {
                Task {
                    try? await app.service.leaveLeague(leagueId)
                    dismiss()
                }
            }
        }
        .confirmationDialog("Créer un nouveau code ?", isPresented: $confirmCode, titleVisibility: .visible) {
            Button("Nouveau code") { regenerate() }
        } message: {
            Text("L'ancien lien et l'ancien code ne marcheront plus. Les membres actuels restent dans la ligue.")
        }
        .confirmationDialog("Nouvelle saison", isPresented: $confirmSeason, titleVisibility: .visible) {
            Button("Commencer aujourd'hui") { newSeason(today: true) }
            Button("Commencer demain") { newSeason(today: false) }
        } message: {
            Text("Mêmes membres et mêmes réglages ; le classement repart de zéro.")
        }
        .confirmationDialog("Retirer \(kick?.handle ?? "") de la ligue ?", isPresented: Binding(get: { kick != nil }, set: { if !$0 { kick = nil } }),
                            titleVisibility: .visible) {
            Button("Retirer", role: .destructive) {
                if let row = kick { remove(row) }
            }
        }
    }

    private func load() async {
        do {
            standings = try await app.service.leagueStandings(leagueId, offset: offset)
            error = nil
        } catch {
            self.error = error.userMessage
        }
    }

    // MARK: Blocs

    private func header(_ s: LeagueStandings) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(s.isOpen ? "Ligue ouverte" : s.season.map { "Ligue · saison \($0)" } ?? "Ligue").labelCaps()
            Text(s.name).font(.cfDisplay)
            HStack(spacing: 6) {
                Image(systemName: s.status == "finished" ? "flag.checkered" : "clock.fill").foregroundStyle(Color.brand)
                if s.isOpen && s.status != "finished" && s.openEnded == true {
                    Text("Sans fin · joue quand tu veux")
                } else {
                    Text(LeagueText.remaining(status: s.status, daysLeft: s.daysLeft, startsIn: s.startsIn, endDate: s.endDate,
                                              endsAt: s.endsAt, timezone: s.timezone))
                }
                if s.status == "active", let day = s.dayIndex, let total = s.totalDays {
                    Text("· jour \(day) sur \(total)").foregroundStyle(Color.inkSoft)
                }
            }
            .font(.cfFootnote.weight(.semibold))
        }
    }

    /// Le quiz du jour de la ligue : une carte à part, jamais confondue avec le 5 du jour de Brainlix.
    @ViewBuilder
    private func quizCard(_ s: LeagueStandings) -> some View {
        switch s.status {
        case "active":
            let today = s.myToday
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quiz de la ligue").labelCaps(Color.inkFixed.opacity(0.7))
                        Text(today?.state == "done" ? "Fait : \(today?.score ?? 0)/\(today?.total ?? 0)"
                             : "\(today?.total ?? s.settings?.questionCount ?? 5) questions aujourd'hui")
                            .font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(Color.inkFixed)
                    }
                    Spacer()
                    Image(systemName: today?.state == "done" ? "checkmark.seal.fill" : "trophy.fill")
                        .font(.system(size: 34)).foregroundStyle(Color.inkFixed.opacity(0.8))
                }
                Text(today?.state == "done" ? "Reviens demain pour le prochain quiz. Les scores du jour sont visibles."
                     : "Le même quiz pour tous les membres, à faire avant minuit. Distinct du \(Brand.dailyName) de Brainlix.")
                    .font(.cfFootnote).foregroundStyle(Color.inkFixed.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                switch today?.state {
                case "done":
                    Button("Voir les scores du jour") { showDay = true }
                        .buttonStyle(InkButtonStyle(fill: Color.inkFixed, text: .white))
                case "in_progress":
                    Button("Reprendre (\(today?.answered ?? 0)/\(today?.total ?? 0))") { playing = true }
                        .buttonStyle(InkButtonStyle(fill: Color.inkFixed, text: .white))
                default:
                    Button("Jouer") { playing = true }
                        .buttonStyle(InkButtonStyle(fill: Color.inkFixed, text: .white))
                }
            }
            .padding(Space.l)
            .background(LinearGradient(colors: [Color.sun, Color(hex: 0xFFB547)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        case "upcoming":
            Label("Premier quiz de la ligue : \((s.startsIn ?? 1) <= 1 ? "demain" : "dans \(s.startsIn ?? 1) jours"). Invite tes amis d'ici là !",
                  systemImage: "hourglass")
                .font(.cfCallout).foregroundStyle(Color.ink)
                .popCard(padding: 14)
        case "finished":
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Ligue terminée").font(.cfTitle3)
                if s.isOwner {
                    Button("Nouvelle saison") { confirmSeason = true }.buttonStyle(.ink)
                    Text("Mêmes membres et mêmes réglages ; le classement repart de zéro.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                } else {
                    Text("Le créateur peut lancer une nouvelle saison.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            .popCard(padding: 14)
        default:
            EmptyView()
        }
    }

    private func ranking(_ s: LeagueStandings) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Classement").labelCaps()
                Spacer()
                Text(s.isOpen ? "bonnes réponses · quiz joués" : "points · jours joués").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            ForEach(s.standings) { row in
                HStack(spacing: Space.m) {
                    Text("\(row.rank)")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(row.rank <= 3 && row.points > 0 ? Color.inkFixed : Color.inkSoft)
                        .frame(width: 36, height: 36)
                        .background(medal(row.rank, points: row.points), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(row.handle).font(.cfTitle3).fontWeight(row.isMe ? .bold : .semibold)
                            if row.isOwner == true {
                                Image(systemName: "crown.fill").font(.caption).foregroundStyle(Color.sun)
                                    .accessibilityLabel("créateur")
                            }
                        }
                        Text(rowDetail(row, in: s))
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                    if let place = podiumPlace(row, in: s) {
                        Image(systemName: place == 1 ? "trophy.fill" : "medal.fill")
                            .font(.title3)
                            .foregroundStyle(medal(place, points: 1))
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                            .accessibilityLabel("Podium : \(place == 1 ? "1er" : "\(place)e")")
                    }
                    Text("\(row.points)").font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                }
                .padding(12)
                .background(row.isMe ? Color.brand.opacity(0.12) : Color.paperRaised,
                            in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(row.isMe ? Color.brand : .clear, lineWidth: 2))
                .accessibilityElement(children: .combine)
                .contextMenu {
                    if !row.isMe {
                        Button("Signaler \(row.handle)", systemImage: "flag") {
                            report = ReportTarget(kind: .user, targetId: row.id, name: row.handle)
                        }
                    }
                    if s.isOwner, !row.isMe {
                        Button("Retirer de la ligue", systemImage: "person.badge.minus", role: .destructive) { kick = row }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func settingsCard(_ s: LeagueStandings) -> some View {
        if let settings = s.settings {
            VStack(alignment: .leading, spacing: 6) {
                Text("Réglages").labelCaps()
                Text(LeagueText.settings(settings)).font(.cfCallout)
                Text("\(s.members ?? s.standings.count) membre\((s.members ?? 0) > 1 ? "s" : "") sur \(settings.maxMembers) · "
                     + (s.isOpen && s.openEnded == true ? "depuis le \(DateText.short(s.startDate))"
                                                        : "du \(DateText.short(s.startDate)) au \(DateText.short(s.endDate))"))
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .popCard(padding: 14)
        }
    }

    private func invite(_ s: LeagueStandings) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ShareLink(item: Brand.leagueURL(code: s.inviteCode),
                      message: Text("Rejoins ma ligue « \(s.name) » sur \(Brand.name). Code : \(s.inviteCode)")) {
                HStack {
                    Text("Inviter dans la ligue")
                    Spacer()
                    Text(s.inviteCode).font(.system(.callout, design: .monospaced)).opacity(0.7)
                }
            }
            .buttonStyle(.ink)
            if s.isOwner {
                Button("Créer un nouveau code") { confirmCode = true }.buttonStyle(.textLink)
            }
        }
    }

    // MARK: Actions (créateur)

    private func regenerate() {
        Task {
            do {
                _ = try await app.service.leagueRegenerateCode(league: leagueId)
                await load()
            } catch { self.error = error.userMessage }
        }
    }

    private func newSeason(today: Bool) {
        Task {
            do {
                standings = try await app.service.leagueNewSeason(league: leagueId, startToday: today)
                offset = 0
                Haptics.success()
            } catch { self.error = error.userMessage }
        }
    }

    private func addQuiz() {
        busy = true
        Task {
            do {
                standings = try await app.service.leagueAddQuiz(league: leagueId)
                Haptics.success()
            } catch { self.error = error.userMessage }
            busy = false
        }
    }

    private func endLeague() {
        busy = true
        Task {
            do {
                standings = try await app.service.leagueEnd(league: leagueId)
                Haptics.success()
            } catch { self.error = error.userMessage }
            busy = false
        }
    }

    private func remove(_ row: LeagueStandings.Row) {
        Task {
            do {
                try await app.service.leagueKick(league: leagueId, user: row.id)
                await load()
            } catch { self.error = error.userMessage }
            kick = nil
        }
    }
}

/// Un quiz d'une ligue ouverte (pour les feuilles et le plein écran).
struct QuizPick: Identifiable {
    let n: Int
    var id: Int { n }
}

extension LeagueView {
    /// Place sur le podium : définitive une fois la ligue terminée, sinon celle qu'on aurait maintenant
    /// (seulement si la ligue compte assez de joueurs actifs).
    fileprivate func podiumPlace(_ row: LeagueStandings.Row, in standings: LeagueStandings) -> Int? {
        if let results = standings.results, !results.isEmpty {
            return results.first { $0.id == row.id }?.place
        }
        guard standings.status != "finished", let podium = standings.podium, podium.activePlayers >= podium.minPlayers,
              row.points > 0 else { return nil }
        let eligible = standings.standings.filter { standings.isOpen ? ($0.answered ?? 0) > 0 : $0.days >= podium.minDays }
        guard let place = eligible.firstIndex(where: { $0.id == row.id }), place < 3 else { return nil }
        return place + 1
    }

    fileprivate func rowDetail(_ row: LeagueStandings.Row, in s: LeagueStandings) -> String {
        if s.isOpen {
            let total = s.quizzes?.count ?? 0
            return (row.answered ?? 0) == 0 ? "pas encore joué" : "\(row.days)/\(total) quiz fini\(row.days > 1 ? "s" : "")"
        }
        return "\(row.days)/\(s.totalDays ?? row.days) jour\(row.days > 1 ? "s" : "") · \(DurationFormat.clock(milliseconds: row.totalMs))"
    }

    /// Ligue ouverte : la liste des quiz, à jouer dans l'ordre qu'on veut ; le créateur en ajoute et peut terminer la ligue.
    @ViewBuilder
    fileprivate func openQuizzes(_ s: LeagueStandings) -> some View {
        let quizzes = s.quizzes ?? []
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Les quiz").labelCaps()
                Spacer()
                Text("sans chrono · une fois chacun").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            ForEach(quizzes) { quiz in
                HStack(spacing: Space.m) {
                    Text("\(quiz.n)")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(quiz.state == "done" ? Color.white : Color.inkFixed)
                        .frame(width: 38, height: 38)
                        .background(quiz.state == "done" ? Color.correct : Color.sun, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiz \(quiz.n)").font(.cfTitle3)
                        Text(quiz.state == "done" ? "Fait : \(quiz.score)/\(quiz.total)"
                             : quiz.state == "in_progress" ? "En cours : \(quiz.answered)/\(quiz.total)" : "\(quiz.total) questions")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Spacer(minLength: 0)
                    if quiz.state == "done" {
                        Button("Scores") { quizScores = QuizPick(n: quiz.n) }
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.brand)
                    } else if s.status == "active" {
                        Button(quiz.state == "in_progress" ? "Reprendre" : "Jouer") { playingQuiz = QuizPick(n: quiz.n) }
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 14).frame(minHeight: 38)
                            .background(Color.sun, in: Capsule())
                    }
                }
                .padding(12)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            if s.isOwner, s.status == "active" {
                if quizzes.count < (s.quizMax ?? 30) {
                    Button { addQuiz() } label: {
                        Label("Ajouter un quiz", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ink)
                    .disabled(busy)
                }
                Button("Terminer la ligue") { confirmEnd = true }
                    .buttonStyle(.textLink)
                    .frame(maxWidth: .infinity)
                    .disabled(busy)
            } else if s.status == "finished" {
                Label("Ligue terminée : le classement est définitif.", systemImage: "flag.checkered")
                    .font(.cfCallout).foregroundStyle(Color.ink)
                    .popCard(padding: 14)
            }
        }
    }

    /// Podium : à la fin, les 3 premiers (et le trophée du 1er) ; avant, la règle.
    @ViewBuilder
    fileprivate func podiumCard(_ standings: LeagueStandings) -> some View {
        if let results = standings.results, !results.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Podium").labelCaps()
                HStack(alignment: .bottom, spacing: Space.s) {
                    ForEach([2, 1, 3], id: \.self) { place in
                        if let r = results.first(where: { $0.place == place }) {
                            VStack(spacing: 4) {
                                Image(systemName: place == 1 ? "trophy.fill" : "medal.fill")
                                    .font(place == 1 ? .title : .title3)
                                    .foregroundStyle(medal(place, points: 1))
                                Text(r.handle).font(.system(.footnote, design: .rounded).weight(.heavy))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text("\(r.points) pts").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(medal(place, points: 1).opacity(0.6))
                                    .frame(height: place == 1 ? 46 : place == 2 ? 32 : 22)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                if let mine = standings.myPlace {
                    Text(mine == 1 ? "Tu gagnes la ligue et le trophée « Vainqueur de ligue » !" : "Tu finis \(mine)e : bravo !")
                        .font(.cfCallout.weight(.semibold)).foregroundStyle(Color.ink)
                }
            }
            .popCard(padding: 14)
        } else if let reward = standings.myReward {
            // Saisons d'avant 1.2 : un coffre de podium.
            HStack(spacing: Space.m) {
                ChestView(tier: reward.tier, open: true).frame(width: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tu as fini \(reward.place == 1 ? "1er" : "\(reward.place)e") !").font(.cfTitle3)
                    Text("\(reward.tier.title) gagné.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .popCard(padding: 14)
        } else if standings.status != "finished", let podium = standings.podium {
            HStack(spacing: Space.m) {
                Image(systemName: "trophy.fill").font(.system(size: 34)).foregroundStyle(Color.sun)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 2) {
                    if podium.activePlayers < podium.minPlayers {
                        let missing = podium.minPlayers - podium.activePlayers
                        Text("Encore \(missing) joueur\(missing > 1 ? "s" : "") actif\(missing > 1 ? "s" : "")")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("Il faut \(podium.minPlayers) joueurs qui jouent pour qu'il y ait un podium à la fin.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Podium et trophée").font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text(standings.isOpen ? "À la fin : 1er, 2e et 3e, et le trophée « Vainqueur de ligue » pour le 1er."
                             : "À la fin : 1er, 2e et 3e (au moins \(podium.minDays) jours joués), et le trophée « Vainqueur de ligue » pour le 1er.")
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

// MARK: - Quiz du jour de la ligue

@MainActor
@Observable
final class LeagueQuizModel {
    enum Stage: Equatable {
        case loading
        case question
        case finished(LeagueDayResult)
        case failed(String)
    }

    let leagueId: UUID
    /// Ligue ouverte : numéro du quiz (nil : quiz du jour).
    let quiz: Int?
    private(set) var stage: Stage = .loading
    private(set) var question: Question?
    private(set) var phase: AnswerPhase = .answering
    private(set) var position = 1
    private(set) var total = 5
    private(set) var isRetrying = false
    private var lastVerdict: DailyVerdict?
    private var pendingGiven: GivenAnswer?
    private var pendingMs: Int?
    private var stopwatch = Stopwatch()
    private let service: GameService

    init(leagueId: UUID, quiz: Int? = nil, service: GameService) {
        self.leagueId = leagueId
        self.quiz = quiz
        self.service = service
    }

    private func result() async throws -> LeagueDayResult {
        if let quiz { return try await service.leagueQuizResult(league: leagueId, quiz: quiz) }
        return try await service.leagueDayResult(league: leagueId)
    }

    func start() async {
        do {
            let day = try await result()
            total = day.total
            if day.me.answered >= day.total {
                stage = .finished(day)
            } else {
                await load(position: day.me.answered + 1)
            }
        } catch {
            stage = .failed((error as? LocalizedError)?.errorDescription ?? "Quiz indisponible.")
        }
    }

    private func load(position: Int) async {
        self.position = position
        do {
            let response: DailyQuestionResponse
            if let quiz {
                response = try await service.leagueQuizQuestion(league: leagueId, quiz: quiz, position: position)
            } else {
                response = try await service.leagueQuestion(league: leagueId, position: position)
            }
            guard let q = response.question else { await showResult(); return }
            question = q
            phase = .answering
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed((error as? LocalizedError)?.errorDescription ?? "Quiz indisponible.")
        }
    }

    func questionDisplayed() { stopwatch.start() }
    func pause() { stopwatch.pause() }
    func resume() { if stage == .question && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) {
        guard phase.isAnswering else { return }
        stopwatch.pause()
        let ms = stopwatch.elapsedMilliseconds
        pendingGiven = given
        pendingMs = ms
        phase = .submitting(given)
        Task { await send(given: given, ms: ms) }
    }

    func retry() {
        guard let given = pendingGiven else { return }
        isRetrying = false
        Task { await send(given: given, ms: pendingMs) }
    }

    private func send(given: GivenAnswer, ms: Int?) async {
        do {
            let verdict: DailyVerdict
            if let quiz {
                verdict = try await service.leagueQuizAnswer(league: leagueId, quiz: quiz, position: position, given: given)
            } else {
                verdict = try await service.leagueAnswer(league: leagueId, position: position, given: given, clientMs: ms)
            }
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            lastVerdict = verdict
            Feedback.answer(correct)
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pendingGiven = nil
        } catch {
            isRetrying = true
        }
    }

    var isLast: Bool { position >= total }

    /// Passage à la question suivante en cours : un double appui ne doit pas sauter une question.
    private var advancing = false

    func next() async {
        guard !advancing else { return }
        advancing = true
        defer { advancing = false }
        if lastVerdict?.finished == true || isLast { await showResult() } else { await load(position: position + 1) }
    }

    private func showResult() async {
        stage = .loading
        do { stage = .finished(try await result()) } catch {
            stage = .failed((error as? LocalizedError)?.errorDescription ?? "Résultat indisponible.")
        }
    }
}

struct LeagueQuizView: View {
    let leagueId: UUID
    let name: String
    var quiz: Int?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: LeagueQuizModel?
    /// Fin du quiz déjà notée pour la pub entre les parties (les scores réapparaissent après une pub).
    @State private var countedFinish = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model { content(model) } else { ProgressView() }
        }
        .task {
            guard model == nil else { return }
            let session = LeagueQuizModel(leagueId: leagueId, quiz: quiz, service: app.service)
            model = session
            await session.start()
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? model?.resume() : model?.pause()
        }
    }

    @ViewBuilder private func content(_ model: LeagueQuizModel) -> some View {
        switch model.stage {
        case .loading:
            ProgressView().tint(Color.brand)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer()
                Leon(pose: .sad).frame(width: 150)
                Text(message).font(.cfHeadline)
                Button("Fermer") { dismiss() }.buttonStyle(.ink)
                Spacer()
            }
            .padding(Space.gutter)
        case .question:
            if let question = model.question {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    continueTitle: model.isLast ? "Voir les scores" : "Question suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() }
                ) {
                    HStack(spacing: Space.m) {
                        // Le nom de la ligue ne tenait pas à côté du domaine et de la progression : juste le trophée.
                        Image(systemName: "trophy.fill").font(.cfFootnote.weight(.heavy)).foregroundStyle(Color(hex: 0xE08A00))
                            .accessibilityLabel(name)
                        if model.total <= 12 {
                            ProgressPills(current: model.position, total: model.total, color: DomainPalette.color(question.domainId))
                        } else {
                            Text("\(model.position) / \(model.total)").font(.cfNumber).foregroundStyle(Color.inkSoft)
                        }
                        Button { dismiss() } label: { CloseCircle() }
                            .accessibilityLabel(quiz == nil ? "Quitter (tu pourras reprendre avant minuit)" : "Quitter (tu pourras reprendre plus tard)")
                    }
                }
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .overlay(alignment: .bottom) {
                    if model.isRetrying {
                        VStack(spacing: Space.s) {
                            Text("Connexion perdue. Ta réponse est gardée.").font(.cfCallout).foregroundStyle(.white)
                            Button("Renvoyer") { model.retry() }.buttonStyle(.sun)
                        }
                        .padding(Space.m)
                        .background(Color.brandDeep, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        .padding(Space.gutter)
                    }
                }
            }
        case .finished(let day):
            LeagueDayView(day: day, name: name, onClose: {
                Task {
                    // Quiz fini : la pub entre les parties peut passer en quittant les scores (D-110).
                    await app.interstitialBetweenGames()
                    dismiss()
                    await app.refreshProfile()
                }
            })
            .task {
                guard !countedFinish else { return }
                countedFinish = true
                app.noteGameFinished()
            }
        }
    }
}

/// Scores du jour : le mien et ceux des membres.
struct LeagueDayView: View {
    let day: LeagueDayResult
    let name: String
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    Text(day.quiz.map { "\(name) · Quiz \($0)" } ?? "\(name) · \(DateText.long(day.day))").labelCaps()
                    Spacer()
                    Button(action: onClose) { CloseCircle() }.accessibilityLabel("Fermer")
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(day.me.score)").numeral(size: 80).foregroundStyle(Color(hex: 0xE08A00))
                    Text("/\(day.total)").numeral(size: 34).foregroundStyle(Color.inkSoft)
                    Spacer()
                    TallyMark(results: day.myAnswers.compactMap(\.isCorrect)).frame(width: 60)
                }
                Text("\(day.me.score) point\(day.me.score > 1 ? "s" : "") pour la ligue"
                     + (day.quiz == nil ? " · \(DurationFormat.clock(milliseconds: day.me.totalMs))" : ""))
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                if let members = day.members {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.quiz == nil ? "Scores du jour" : "Scores du quiz").labelCaps()
                        ForEach(members) { member in
                            HStack {
                                Text(member.handle).font(.cfTitle3).fontWeight(member.isMe ? .bold : .semibold)
                                Spacer()
                                if member.answered == 0 {
                                    Text("pas encore joué").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                } else {
                                    Text("\(member.score)/\(day.total)").font(.cfNumber)
                                    if day.quiz == nil {
                                        Text(DurationFormat.clock(milliseconds: member.totalMs)).font(.cfFootnote.monospacedDigit())
                                            .foregroundStyle(Color.inkSoft)
                                    }
                                }
                            }
                            .padding(12)
                            .background(member.isMe ? Color.brand.opacity(0.12) : Color.paperRaised,
                                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        }
                    }
                }
                Button("Continuer", action: onClose).buttonStyle(.ink)
            }
            .padding(Space.gutter)
        }
        .background(Color.paper)
    }
}

/// Scores du jour, depuis la page de la ligue.
struct LeagueDaySheet: View {
    let leagueId: UUID
    var quiz: Int?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var day: LeagueDayResult?

    var body: some View {
        Group {
            if let day {
                LeagueDayView(day: day, name: quiz == nil ? "Aujourd'hui" : "Ligue", onClose: { dismiss() })
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.paper)
        .presentationDragIndicator(.visible)
        .task {
            if let quiz {
                day = try? await app.service.leagueQuizResult(league: leagueId, quiz: quiz)
            } else {
                day = try? await app.service.leagueDayResult(league: leagueId)
            }
        }
    }
}

// MARK: - Règles

/// Comment marchent les ligues, en 4 étapes illustrées.
struct LeagueRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Les ligues").font(.cfDisplay).padding(.top, Space.l)
                Text("Une compétition privée entre amis, en deux formats : « ouverte » (des quiz à jouer quand on veut, sans chrono) ou « quiz du jour ».")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                step(1, "Crée ou rejoins une ligue", "Le créateur choisit le format, les questions, les domaines et la difficulté. Partage le lien ou le code.") {
                    Text("K7P2QXMA")
                        .font(.system(.callout, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                step(2, "Ligue ouverte", "Les mêmes quiz pour tous, chacun joué une fois, quand tu veux, sans chrono. 1 point par bonne réponse ; à égalité, le premier à avoir fini passe devant. Le créateur ajoute des quiz et termine la ligue quand il veut.") {
                    Image(systemName: "list.number").font(.largeTitle).foregroundStyle(Color.brand)
                }
                step(3, "Quiz du jour", "Chaque jour, le même quiz pour tous, à faire avant minuit. À égalité, le plus rapide passe devant. Un jour manqué compte 0.") {
                    Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Color(hex: 0xE08A00))
                }
                step(4, "Podium et trophée", "À la fin : 1er, 2e et 3e, et le trophée « Vainqueur de ligue » pour le 1er, s'il y a au moins 3 joueurs.") {
                    HStack(alignment: .bottom, spacing: 2) {
                        podiumStep(2, height: 16)
                        podiumStep(1, height: 26)
                        podiumStep(3, height: 10)
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

    private func podiumStep(_ place: Int, height: CGFloat) -> some View {
        VStack(spacing: 1) {
            Image(systemName: place == 1 ? "trophy.fill" : "medal.fill").foregroundStyle(medal(place, points: 1))
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

/// Message d'erreur avec « Réessayer » (réseau coupé, serveur indisponible).
struct RetryMessage: View {
    let text: String
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Leon(pose: .curious).frame(width: 110)
            Text(text).font(.cfHeadline).fixedSize(horizontal: false, vertical: true)
            Button("Réessayer", action: retry).buttonStyle(.ink)
        }
        .padding(.top, Space.xl)
    }
}
