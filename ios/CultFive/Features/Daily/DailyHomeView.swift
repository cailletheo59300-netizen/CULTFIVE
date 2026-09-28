import SwiftUI
import CultFiveCore

/// Accueil = le rendez-vous du jour. Léon t'accueille, la grande carte violette porte le trait de cinq ;
/// en dessous, quelques cartes utiles (série, erreurs, suggestion, ligue), pas un dashboard.
struct DailyHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showDaily = false
    @State private var playConfig: PlayConfig?
    @State private var suggestion: SkillSummary?
    @State private var league: LeagueSummary?
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
                    rendezVous
                    if let quests { QuestsCard(overview: quests) }
                    column
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
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
        if let skills = try? await app.service.skills() {
            suggestion = skills.filter { $0.answered >= 5 }.min { $0.level < $1.level }
        }
        league = (try? await app.service.leagues())?.first
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
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xF76707))
                    Text("\(streak)").monospacedDigit()
                }
                .font(.cfNumber)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.paperRaised, in: Capsule())
                .accessibilityLabel("Série de \(streak) jours")
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

    @ViewBuilder private var column: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let profile = app.profile {
                EditorialRow(label: "Série", value: profile.streak > 0 ? "\(profile.streak) jour\(profile.streak > 1 ? "s" : "")" : "à lancer",
                             detail: profile.streakFreezes > 0 ? "\(profile.streakFreezes) joker\(profile.streakFreezes > 1 ? "s" : "") de série en réserve" : "Un joker tous les 7 jours d'affilée",
                             symbol: "flame.fill", accent: Color(hex: 0xF76707))
                if profile.activeErrors > 0 {
                    Button { playConfig = PlayConfig(mode: .errors) } label: {
                        EditorialRow(label: "À revoir", value: "\(profile.activeErrors) erreur\(profile.activeErrors > 1 ? "s" : "")",
                                     detail: "Corrige-les pendant qu'elles sont fraîches.", symbol: "arrow.uturn.backward",
                                     accent: .wrong, chevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
            if let suggestion {
                Button { playConfig = PlayConfig(mode: .training, domain: suggestion.domainId) } label: {
                    EditorialRow(label: "Ton terrain à conquérir", value: suggestion.name,
                                 detail: suggestion.rating.placed ? "Cote \(suggestion.rating.formatted) · quelques questions pour progresser"
                                                                  : "Placement \(suggestion.rating.placementGames)/\(CoteCULT.placementGames) · quelques questions pour progresser",
                                 symbol: "scope", accent: DomainPalette.color(suggestion.domainId), chevron: true)
                }
                .buttonStyle(.row)
            }
            if let league {
                Button { app.tab = .friends } label: {
                    EditorialRow(label: "Ligue", value: league.name, detail: "\(league.members) membre\(league.members > 1 ? "s" : "") · classement de la \(league.period == .week ? "semaine" : "du mois")",
                                 symbol: "trophy.fill", accent: Color(hex: 0xFFB020), chevron: true)
                }
                .buttonStyle(.row)
            }
        }
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
