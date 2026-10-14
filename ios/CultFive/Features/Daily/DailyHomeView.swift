import SwiftUI
import CultFiveCore

/// Accueil = le rendez-vous du jour. Léon t'accueille, la grande carte violette porte le trait de cinq ;
/// en dessous, les défis du jour et de la semaine. La série n'est affichée qu'une fois, en haut.
struct DailyHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showDaily = false
    @State private var playConfig: PlayConfig?
    @State private var quests: QuestsOverview?
    /// Objectifs remplis depuis la dernière visite : célébrés en haut de l'accueil.
    @State private var rewards: [QuestsOverview.Reward] = []
    @State private var showStreakHelp = false
    /// Défis remplis, fêtés en plein écran (le bandeau reste en haut de l'accueil ensuite).
    @State private var questMoments: [Celebration] = []
    @State private var showBag = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
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
                    // Les défis (jour, semaine, saison) rapportent neurones et points de saison.
                    SeasonChallengesCard(overview: quests, store: AlbumStore.shared) {
                        app.pendingPass = true
                        app.tab = .album
                    }
                    .id("defis")
                    FreeChestOffer()
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
                // Largeur de l'écran, jamais plus : la page ne bouge que de haut en bas.
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .clearsTabBar()
            .background(Color.paper)
            .refreshable { await reload() }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: app.pendingChallenges, initial: true) { _, go in
                guard go else { return }
                app.pendingChallenges = false
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(Motion.standard) { reader.scrollTo("defis", anchor: .top) }
                }
            }
            }
        }
        .fullScreenCover(isPresented: $showDaily, onDismiss: { Task {
            await reload()
            // Un défi rempli est d'abord fêté ; son coffre s'ouvre à la fin de la fête.
            if questMoments.isEmpty { app.openNewChests() }
        } }) {
            DailySessionView()
        }
        .fullScreenCover(item: $playConfig, onDismiss: { Task {
            await reload()
            // Un défi rempli est d'abord fêté ; son coffre s'ouvre à la fin de la fête.
            if questMoments.isEmpty { app.openNewChests() }
        } }) { config in
            PlaySessionView(config: config)
        }
        .sheet(isPresented: $showBag) { BagView() }
        .fullScreenCover(isPresented: Binding(get: { !questMoments.isEmpty }, set: { if !$0 { questMoments = [] } })) {
            CelebrationSequence(items: questMoments) {
                questMoments = []
                // Le coffre du défi rempli s'ouvre juste après la fête.
                Task {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    await app.refreshProgression()
                    app.openNewChests()
                }
            }
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
        if let fresh = try? await app.service.quests() {
            quests = fresh
            // Les défis remplis font monter le pass : on relit le pass et l'album.
            await AlbumStore.shared.refresh()
            if !fresh.newly.isEmpty {
                withAnimation(Motion.bounce) { rewards = fresh.newly }
                questMoments = fresh.newly.map {
                    .quest(label: $0.label, seeds: $0.seeds, xp: $0.xp, chest: $0.chest.flatMap(ChestTier.init(rawValue:)))
                }
                await app.refreshProfile()
            }
        }
    }

    // MARK: Blocs

    private var topLine: some View {
        // Jokers écrits en toutes lettres quand la ligne a la place, sinon un bouclier et leur nombre.
        ViewThatFits(in: .horizontal) {
            topLineContent(shortDate: false)
            topLineContent(shortDate: true)
        }
        .padding(.top, Space.m)
        .popover(isPresented: $showStreakHelp) {
            streakHelp.presentationCompactAdaptation(.popover)
        }
    }

    /// La date, la série (flamme) et le sac (graines, tickets, jokers, coffres ; pastille : coffres à ouvrir).
    private func topLineContent(shortDate: Bool) -> some View {
        let date = app.daily?.date ?? isoToday
        return HStack(spacing: Space.s) {
            Text(shortDate ? DateText.short(date) : DateText.long(date)).labelCaps()
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let streak = app.profile?.streak, streak > 0 {
                let freezes = app.profile?.streakFreezes ?? 0
                Button { showStreakHelp = true } label: {
                    HStack(spacing: 4) {
                        GameIcon.flame.image.frame(width: 24, height: 24)
                        Text("\(streak)").monospacedDigit()
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .font(.cfNumber)
                    .foregroundStyle(Color.ink)
                    .padding(.leading, 8).padding(.trailing, 12).frame(minHeight: 40)
                    .background(Color.paperRaised, in: Capsule())
                }
                .buttonStyle(.row)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Série de \(streak) jour\(streak > 1 ? "s" : "")" + (freezes > 0 ? ", \(freezes) joker\(freezes > 1 ? "s" : "") de série" : ""))
                .accessibilityHint("Explique la série et les jokers")
            }
            let chests = app.progression?.chests.count ?? 0
            Button { showBag = true } label: {
                GameIcon.bag.image
                    .frame(width: 34, height: 34)
                    .frame(width: 48, height: 40)
                    .background(Color.paperRaised, in: Capsule())
                    .overlay(alignment: .topTrailing) {
                        if chests > 0 {
                            Text("\(chests)")
                                .font(.system(.caption2, design: .rounded).weight(.black)).monospacedDigit()
                                .foregroundStyle(Color(hex: 0x1E1340))
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.sun, in: Capsule())
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.row)
            .accessibilityLabel(chests > 0 ? "Mon sac, \(chests) coffre\(chests > 1 ? "s" : "") à ouvrir" : "Mon sac")
            .accessibilityHint("Neurones, tickets, jokers, coffres")
        }
    }

    /// Bulle ouverte en touchant la flamme : la série et les jokers expliqués.
    private var streakHelp: some View {
        let streak = app.profile?.streak ?? 0
        let freezes = app.profile?.streakFreezes ?? 0
        return VStack(alignment: .leading, spacing: Space.s) {
            Label { Text("\(streak) jour\(streak > 1 ? "s" : "") de série") } icon: { GameIcon.flame.image.frame(width: 24, height: 24) }
                .font(.cfTitle3).foregroundStyle(Color.ink)
            Text("Fais le \(Brand.dailyName) chaque jour pour la faire grandir.")
            Label { Text(freezes > 0 ? "\(freezes) joker\(freezes > 1 ? "s" : "") de série" : "Aucun joker pour l'instant") }
                  icon: { GameIcon.joker.image.frame(width: 22, height: 22) }
                .font(.cfCallout.weight(.bold)).foregroundStyle(Color.ink)
                .padding(.top, 4)
            Text("Si tu rates un jour, un joker sauve ta série automatiquement. Tu en gagnes un tous les 7 jours d'affilée (2 au maximum).")
        }
        .font(.cfFootnote)
        .foregroundStyle(Color.inkSoft)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Space.m)
        .frame(width: 290, alignment: .leading)
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
