import SwiftUI
import CultFiveCore

/// Accueil = le rendez-vous du jour. Léon t'accueille, la grande carte violette porte le trait de cinq ;
/// en dessous, un seul bloc « Aujourd'hui » (erreurs, domaine à travailler, ligue) où chaque ligne montre
/// son information en grand plutôt qu'une icône générique. La série n'est affichée qu'une fois, en haut.
struct DailyHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showDaily = false
    @State private var playConfig: PlayConfig?
    @State private var suggestion: SkillSummary?
    @State private var league: LeagueSummary?
    /// Classement en cours de la première ligue (ma place, fin de période).
    @State private var standings: LeagueStandings?
    @State private var quests: QuestsOverview?
    /// Objectifs remplis depuis la dernière visite : célébrés en haut de l'accueil.
    @State private var rewards: [QuestsOverview.Reward] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    topLine
                    LeonSays(text: leonLine, color: .brand, pose: app.daily?.state == .done ? .proud : .wave,
                             curl: min(1, 0.2 + Double(app.profile?.streak ?? 0) * 0.08), size: 92)
                    if !rewards.isEmpty {
                        QuestRewardBanner(rewards: rewards)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    StreakRescueOffer()
                    rendezVous
                    if let quests { QuestsCard(overview: quests) }
                    FreeChestOffer()
                    today
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
            .clearsTabBar()
            .background(Color.paper)
            .refreshable { await reload() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showDaily, onDismiss: { Task { await reload() } }) {
            DailySessionView()
        }
        .fullScreenCover(item: $playConfig, onDismiss: { Task { await reload() } }) { config in
            PlaySessionView(config: config)
        }
        .task {
            await reload()
            #if DEBUG
            if let screen = Demo.screen, [.question, .reveal, .result, .share].contains(screen) { showDaily = true }
            #endif
        }
    }

    private func reload() async {
        await app.refreshDaily()
        await app.refreshProfile()
        await app.refreshAdStatus()
        if let skills = try? await app.service.skills() {
            suggestion = skills.filter { $0.answered >= 5 }.min { $0.level < $1.level }
        }
        league = (try? await app.service.leagues())?.first
        if let league { standings = try? await app.service.leagueStandings(league.id, offset: 0) } else { standings = nil }
        if let fresh = try? await app.service.quests() {
            quests = fresh
            if !fresh.newly.isEmpty {
                withAnimation(Motion.bounce) { rewards = fresh.newly }
                Haptics.success()
                await app.refreshProfile()
            }
        }
    }

    // MARK: Blocs

    private var topLine: some View {
        HStack(spacing: Space.s) {
            Text(DateText.long(app.daily?.date ?? isoToday)).labelCaps()
            Spacer()
            if let streak = app.profile?.streak, streak > 0 {
                let freezes = app.profile?.streakFreezes ?? 0
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xF76707))
                    Text("\(streak)").monospacedDigit()
                    if freezes > 0 {
                        Text("· \(freezes) joker\(freezes > 1 ? "s" : "")")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .font(.cfNumber)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.paperRaised, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Série de \(streak) jour\(streak > 1 ? "s" : "")" + (freezes > 0 ? ", \(freezes) joker\(freezes > 1 ? "s" : "") de série" : ""))
            }
            if let chests = app.progression?.chests, !chests.isEmpty {
                ChestPill(count: chests.count) { app.openChests() }
            }
            if let seeds = app.profile?.seeds {
                SeedsAmount(amount: seeds).font(.cfNumber)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.paperRaised, in: Capsule())
            }
        }
        .padding(.top, Space.m)
    }

    /// La grande carte du jour : dégradé violet, trait de cinq, bouton soleil.
    private var rendezVous: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Brand.dailyName).labelCaps(Color.sun)
                    Text(stateTitle)
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.s)
                TallyMark(strokes: strokes, onInk: true)
                    .frame(width: 84)
                    .onTapGesture { showDaily = true }
            }
            Text(stateDetail).font(.cfCallout).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            switch app.daily?.state {
            case .done:
                Button("Voir mon résultat") { showDaily = true }.buttonStyle(.inverted)
            case .inProgress:
                Button("Reprendre") { showDaily = true }.buttonStyle(.sun)
            default:
                Button("C'est parti !") { showDaily = true }.buttonStyle(.sun).disabled(app.daily == nil)
            }
        }
        .padding(Space.l)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(alignment: .topTrailing) {
            // Deux bulles décoratives : du relief sans image.
            ZStack {
                Circle().fill(.white.opacity(0.08)).frame(width: 150).offset(x: 50, y: -50)
                Circle().fill(Color.sun.opacity(0.18)).frame(width: 60).offset(x: -70, y: 10)
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color.brand.opacity(0.35), radius: 18, y: 10)
    }

    private var errorsCount: Int { app.profile?.activeErrors ?? 0 }

    /// « Aujourd'hui » : un seul bloc, lignes séparées d'un trait fin. Masqué s'il n'y a rien à proposer.
    @ViewBuilder private var today: some View {
        if errorsCount > 0 || suggestion != nil || league != nil {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Aujourd'hui").font(.cfHeadline)
                VStack(spacing: 0) {
                    if errorsCount > 0 {
                        Button { playConfig = PlayConfig(mode: .errors) } label: {
                            TodayRow(title: errorsCount > 1 ? "erreurs à revoir" : "erreur à revoir",
                                     detail: "Corrige-les pendant qu'elles sont fraîches.") {
                                bigNumber("\(errorsCount)", color: .wrong)
                            }
                        }
                        .buttonStyle(.row)
                    }
                    if let suggestion {
                        // Le bandeau coloré se sépare de lui-même : pas de trait autour.
                        Button { playConfig = PlayConfig(mode: .training, domain: suggestion.domainId) } label: {
                            TerrainRow(skill: suggestion)
                        }
                        .buttonStyle(.row)
                    }
                    if let league {
                        if errorsCount > 0 && suggestion == nil { hairline }
                        Button { app.tab = .friends } label: {
                            TodayRow(title: league.name, detail: leagueDetail(league)) {
                                if let me = standings?.standings.first(where: \.isMe) {
                                    bigNumber(me.rank == 1 ? "1er" : "\(me.rank)e", color: .brand)
                                } else {
                                    bigNumber("\(league.members)", color: .brand)
                                }
                            }
                        }
                        .buttonStyle(.row)
                    }
                }
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
        }
    }

    private var hairline: some View {
        Rectangle().fill(Color.hairline).frame(height: 1).padding(.horizontal, Space.m)
    }

    private func bigNumber(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.6)
    }

    /// « sur 8 · classement de la semaine, fin dans 3 j » ; à défaut de classement, le nombre de membres.
    private func leagueDetail(_ league: LeagueSummary) -> String {
        let period = league.period == .week ? "de la semaine" : "du mois"
        guard let standings, standings.standings.contains(where: \.isMe) else {
            // Le nombre de membres est déjà affiché en grand à gauche.
            return "membre\(league.members > 1 ? "s" : "") · classement \(period)"
        }
        var parts = ["sur \(standings.standings.count)", "classement \(period)"]
        if let days = DailyHomeView.daysLeft(until: standings.endDate) {
            parts.append(days <= 0 ? "dernier jour" : "fin dans \(days) j")
        }
        return parts.joined(separator: " · ")
    }

    /// Jours restants jusqu'à la fin de période (date « yyyy-MM-dd » incluse).
    static func daysLeft(until isoDate: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: isoDate) else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: end)).day
    }

    // MARK: Textes

    private var isoToday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Ce que Léon dit en haut de l'accueil.
    private var leonLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let hello = hour >= 18 || hour < 5 ? "Bonsoir" : "Coucou"
        let name = app.profile.map { " \($0.handle)" } ?? ""
        switch app.daily?.state {
        case .done: return "Bravo\(name) ! On se retrouve demain."
        case .inProgress: return "Tu t'es arrêté en route. On finit ?"
        case .available: return "\(hello)\(name) ! Ton 5 du jour t'attend."
        case nil: return "\(hello)\(name) !"
        }
    }

    private var strokes: [TallyStroke] {
        guard let daily = app.daily else { return Array(repeating: .empty, count: 5) }
        switch daily.state {
        case .available: return [.correct, .correct, .correct, .correct, .ready]
        case .inProgress:
            var strokes = daily.answers.map { $0 ? TallyStroke.correct : .wrong }
            if strokes.count < 5 { strokes.append(.current) }
            return strokes
        case .done: return daily.answers.map { $0 ? .correct : .wrong }
        }
    }

    private var stateTitle: String {
        switch app.daily?.state {
        case .available: return "5 questions,\nc'est parti ?"
        case .inProgress: return "Question \(app.daily?.nextPosition ?? 1) sur 5"
        case .done: return "\(app.daily?.score ?? 0)/5 aujourd'hui"
        case nil: return "Ton 5 du jour arrive…"
        }
    }

    private var stateDetail: String {
        guard let daily = app.daily else { return "" }
        switch daily.state {
        case .available: return "Cinq questions variées. Environ cinq minutes."
        case .inProgress: return "Tes réponses sont gardées. Reprends où tu t'es arrêté."
        case .done:
            return "Le prochain dans \(DurationFormat.countdown(seconds: daily.secondsUntilNext))."
        }
    }
}

/// Carte d'information : pastille d'icône colorée, rubrique, valeur, précision. Pressable si `chevron`.
struct EditorialRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var symbol: String? = nil
    var accent: Color? = nil
    var chevron = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            let tint = accent ?? .brand
            Image(systemName: symbol ?? "sparkles")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).labelCaps()
                Text(value).font(.cfTitle3).foregroundStyle(Color.ink)
                if let detail {
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if chevron {
                Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
            }
        }
        .popCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Ligne du bloc « Aujourd'hui » : l'information en grand à gauche (chiffre, rang), puis le titre et une précision.
private struct TodayRow<Leading: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(spacing: 14) {
            leading()
                .frame(minWidth: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cfTitle3).foregroundStyle(Color.ink).lineLimit(2)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.5))
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Domaine à travailler : bandeau à la couleur du domaine, nom en grand, Elo (ou placement) à droite.
private struct TerrainRow: View {
    let skill: SkillSummary

    var body: some View {
        let color = DomainPalette.color(skill.domainId)
        let on = DomainPalette.onColor(skill.domainId)
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ton terrain à conquérir").font(.cfLabel).tracking(0.6).textCase(.uppercase).foregroundStyle(on.opacity(0.8))
                Text(skill.name).font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(on)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                if skill.rating.placed {
                    Text(skill.rating.formatted).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                    Text(skill.rating.rank.name).font(.system(.caption, design: .rounded).weight(.bold)).opacity(0.8)
                } else {
                    Text(skill.rating.formatted).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                        .opacity(0.8)
                    Text(skill.rating.provisionalLabel)
                        .font(.system(.caption, design: .rounded).weight(.bold)).monospacedDigit().opacity(0.8)
                }
            }
            .foregroundStyle(on)
            Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(on.opacity(0.7))
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 14)
        .background(color, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .padding(6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Lance une partie classée dans ce domaine")
    }
}
