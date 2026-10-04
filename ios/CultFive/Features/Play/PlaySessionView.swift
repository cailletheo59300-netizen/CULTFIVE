import SwiftUI
import CultFiveCore

struct PlaySessionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PlaySessionModel?
    /// Réglages de la partie en cours (« Rejouer » et « Mes erreurs » enchaînent sans refermer l'écran).
    @State private var config: PlayConfig
    /// Partie déjà comptée pour la pub entre les parties.
    @State private var countedGame: UUID?
    @State private var confirmQuit = false

    init(config: PlayConfig) {
        _config = State(initialValue: config)
    }

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .task(id: config.id) {
            let session = PlaySessionModel(config: config, service: app.service, queue: app.queue, cache: app.cache,
                                           seeds: app.profile?.seeds, tickets: app.progression?.tickets)
            model = session
            await session.start()
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? model?.resume() : model?.pause()
        }
    }

    @ViewBuilder
    private func content(_ model: PlaySessionModel) -> some View {
        switch model.stage {
        case .loading:
            ProgressView()
        case .failed(let message), .empty(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer()
                Leon(color: accent, pose: .curious).frame(width: 160)
                Text(message).font(.cfHeadline).fixedSize(horizontal: false, vertical: true)
                Button("Fermer") { close() }.buttonStyle(.ink)
                Spacer()
            }
            .padding(Space.gutter)
        case .intro:
            PlayIntroView(config: config, domainName: config.domain.map { app.domainName($0) },
                          count: model.questions.count, onGo: { model.play() }, onClose: { close() })
                .transition(.opacity)
        case .playing:
            if let question = model.current {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    removedOptions: model.removedOptions,
                    badge: model.badge,
                    continueTitle: model.isLast ? "Terminer" : "Suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() },
                    trailing: { header(model) },
                    help: { helpBar(model, question: question) }
                )
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                // Chrono : à l'échéance, la question compte comme ratée.
                .task(id: model.deadline) {
                    guard let deadline = model.deadline else { return }
                    let wait = deadline.timeIntervalSinceNow
                    if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
                    guard !Task.isCancelled, model.deadline == deadline else { return }
                    model.timeUp()
                }
            }
        case .summary(let summary):
            PlaySummaryView(config: config, summary: summary, sessionId: model.currentSessionId,
                            onAgain: { restart(config.again()) },
                            showErrors: config.mode != .errors && ((app.profile?.activeErrors ?? 0) > 0 || summary.correct < summary.total),
                            onErrors: { restart(PlayConfig(mode: .errors)) },
                            onOpenChests: { closeThenOpenChests() },
                            onCorrect: { Task { await model.startCorrection { try await app.watchCorrectionAd(session: $0) } } },
                            onClose: { close() })
                .task(id: config.id) {
                    guard countedGame != config.id else { return }
                    countedGame = config.id
                    app.ads.noteGameFinished()
                }
        case .correction:
            if let question = model.correctionQuestion {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.correctionPhase,
                    continueTitle: model.correctionIsLast ? "Voir le bilan" : "Suivante",
                    onSubmit: { model.submitCorrection($0) },
                    onContinue: { Task { await model.nextCorrection() } }
                ) {
                    HStack(spacing: Space.m) {
                        Text("Correction \(model.correctionIndex + 1)/\(model.correctionQuestions.count)")
                            .font(.system(.footnote, design: .rounded).weight(.heavy)).monospacedDigit()
                            .foregroundStyle(Color.inkSoft)
                        Button { Task { await model.abandonCorrection() } } label: { CloseCircle() }
                            .accessibilityLabel("Arrêter la correction")
                    }
                }
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private var accent: Color {
        config.domain.map(DomainPalette.color) ?? .brand
    }

    private func accent(for model: PlaySessionModel) -> Color {
        model.current.map { DomainPalette.color($0.domainId) } ?? accent
    }

    /// Bilan affiché : une pub entre les parties peut passer en le quittant.
    private var atSummary: Bool {
        if case .summary = model?.stage { return true }
        return false
    }

    private func restart(_ next: PlayConfig) {
        let betweenGames = atSummary
        Task {
            if betweenGames { await app.interstitialBetweenGames() }
            model = nil
            config = next
        }
    }

    private func header(_ model: PlaySessionModel) -> some View {
        HStack(spacing: Space.m) {
            if let deadline = model.deadline, let total = config.timer {
                TimerRing(deadline: deadline, total: TimeInterval(total), color: accent(for: model))
            }
            if model.isOffline {
                Image(systemName: "wifi.slash").foregroundStyle(Color.inkSoft).accessibilityLabel("Hors ligne")
            }
            if model.questions.count <= 12 {
                ProgressPills(current: model.index + 1, total: model.questions.count, color: accent(for: model))
            } else {
                Text("\(model.index + 1) / \(model.questions.count)").font(.cfNumber).foregroundStyle(Color.inkSoft)
            }
            // Une seule sortie : ce qui a été répondu compte toujours (quitter ne peut pas effacer une partie classée).
            Button {
                if model.results.isEmpty { close() } else { confirmQuit = true }
            } label: {
                CloseCircle()
            }
            .accessibilityLabel("Quitter la partie")
            .confirmationDialog("Quitter la partie ?", isPresented: $confirmQuit, titleVisibility: .visible) {
                Button("Quitter") { Task { await model.finish() } }
                Button("Continuer la partie", role: .cancel) {}
            } message: {
                let n = model.results.count
                Text((n > 1 ? "Tes \(n) réponses sont gardées et comptent " : "Ta réponse est gardée et compte ")
                     + (config.countsForElo ? "(Elo, XP, défis)" : "(XP, défis)")
                     + ". Les questions restantes ne seront pas jouées.")
            }
        }
    }

    @ViewBuilder
    private func helpBar(_ model: PlaySessionModel, question: Question) -> some View {
        let helps = model.availableHelps(for: question)
        VStack(alignment: .leading, spacing: Space.s) {
            if model.shieldTriggered {
                HStack(spacing: Space.s) {
                    Image(systemName: "shield.lefthalf.filled").foregroundStyle(Color.brand).accessibilityHidden(true)
                    Text("Bouclier ! Encore un essai.").font(.cfCallout.weight(.bold)).foregroundStyle(Color.ink)
                }
                .popCard(padding: 12, radius: Radius.s)
                .transition(.scale.combined(with: .opacity))
            } else if model.shieldArmed {
                Label("Bouclier actif : une erreur te donnera un second essai", systemImage: "shield.fill")
                    .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.brand)
            }
            if let text = model.helpText {
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Color(hex: 0xFFB020)).accessibilityHidden(true)
                    Text(text).font(.cfCallout).foregroundStyle(Color.ink)
                }
                .popCard(padding: 12, radius: Radius.s)
            }
            if !helps.isEmpty {
                // Solde visible là où on se demande si on a de quoi payer ; les aides en grille de 2 colonnes.
                HStack {
                    Text("Aides").labelCaps()
                    Spacer()
                    if let balance = model.seedsBalance {
                        SeedsAmount(amount: balance)
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(Color.correct.opacity(0.12), in: Capsule())
                            .contentTransition(.numericText(value: Double(balance)))
                            .animation(Motion.standard, value: balance)
                            .accessibilityLabel("Tu as \(balance) \(balance > 1 ? Brand.currencyPlural : Brand.currencySingular)")
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
                    ForEach(helps, id: \.self) { kind in
                        helpButton(model, kind: kind)
                    }
                }
            }
            if let error = model.helpError {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private func helpButton(_ model: PlaySessionModel, kind: HelpKind) -> some View {
        let tickets = model.tickets.count(kind)
        return Button {
            Task { await model.useHelp(kind) }
        } label: {
            HStack(spacing: 8) {
                helpIcon(kind, ticket: tickets > 0).frame(width: 30, height: 30)
                Text(title(kind)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if model.pendingHelp == kind {
                    ProgressView().controlSize(.mini)
                } else if tickets > 0 {
                    Text("× \(tickets)").monospacedDigit()
                        .accessibilityLabel("\(tickets) ticket\(tickets > 1 ? "s" : "")")
                } else {
                    SeedsAmount(amount: kind.cost, color: .inkSoft)
                }
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.row)
        .foregroundStyle(Color.ink)
        .disabled(model.pendingHelp != nil || !model.canAfford(kind))
        .opacity(model.pendingHelp == kind ? 0.75 : 1)
    }

    /// Ticket 3D quand on en a un, sinon le symbole de l'aide.
    @ViewBuilder
    private func helpIcon(_ kind: HelpKind, ticket: Bool) -> some View {
        switch kind {
        case .fiftyFifty where ticket: GameIcon.ticketFifty.image
        case .hint where ticket: GameIcon.ticketHint.image
        case .fiftyFifty: Text("½").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Color(hex: 0x1C7ED6))
        case .hint: Image(systemName: "lightbulb.fill").foregroundStyle(Color(hex: 0xF2A900))
        case .context: Image(systemName: "text.book.closed.fill").foregroundStyle(Color.brand)
        case .secondChance: Image(systemName: "shield.fill").foregroundStyle(Color.brand)
        }
    }

    private func title(_ kind: HelpKind) -> String {
        switch kind {
        case .fiftyFifty: return "50/50"
        case .hint: return "Indice"
        case .context: return "Contexte"
        case .secondChance: return "Bouclier"
        }
    }

    private func close() {
        let betweenGames = atSummary
        Task {
            if betweenGames { await app.interstitialBetweenGames() }
            dismiss()
            await app.refreshProfile()
            await app.syncPending()
        }
    }

    /// Les coffres s'ouvrent en plein écran depuis l'app : on ferme d'abord la partie.
    private func closeThenOpenChests() {
        dismiss()
        Task {
            await app.refreshProfile()
            try? await Task.sleep(nanoseconds: 600_000_000)
            app.openChests()
        }
    }
}

struct PlaySummaryView: View {
    let config: PlayConfig
    let summary: PlaySessionModel.PlaySummary
    var sessionId: UUID? = nil
    var onAgain: () -> Void
    var showErrors = false
    var onErrors: () -> Void = {}
    var onOpenChests: () -> Void = {}
    var onCorrect: () -> Void = {}
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @State private var appeared = false
    /// Coffres en attente, relus après l'envoi de la partie (niveau, trophée…).
    @State private var chestsWaiting = 0
    /// Moments forts de la partie (niveau, rang, trophée), fêtés en plein écran une seule fois.
    @State private var celebrations: [Celebration] = []
    @State private var celebrated = false

    private var accent: Color { config.domain.map(DomainPalette.color) ?? .brand }
    private var rate: Double { summary.total > 0 ? Double(summary.correct) / Double(summary.total) : 0 }
    private var perfect: Bool { summary.total > 0 && summary.correct == summary.total }
    /// Le profil n'est rafraîchi qu'à la fermeture : il porte encore l'XP d'avant la partie.
    private var levelUp: Int? {
        guard let before = app.profile?.xpTotal, let xp = summary.xp, xp > 0 else { return nil }
        let old = XPLevel(totalXP: before).level, new = XPLevel(totalXP: before + xp).level
        return new > old ? new : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    DomainTag(domainId: config.domain ?? "", name: config.domain.map { app.domainName($0) } ?? config.title)
                    Text(config.title).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Button(action: onClose) { CloseCircle() }
                        .accessibilityLabel("Fermer")
                }
                VStack(spacing: Space.s) {
                    Leon(color: accent, pose: rate >= 0.7 ? .proud : (rate >= 0.4 ? .wave : .curious), rainbow: perfect)
                        .frame(width: 150)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(summary.correct)").numeral(size: 96).foregroundStyle(accent)
                            .scaleEffect(appeared ? 1 : 0.4)
                        Text("/\(summary.total)").numeral(size: 40).foregroundStyle(Color.inkSoft)
                    }
                    Text(perfect ? "Sans faute !" : rate >= 0.7 ? "Belle partie !" : rate >= 0.4 ? "Pas mal du tout." : "Chaque erreur t'apprend quelque chose.")
                        .font(.cfHeadline).multilineTextAlignment(.center)
                    if summary.bestStreak >= 3 {
                        Label("Meilleure série : \(summary.bestStreak) d'affilée", systemImage: "flame.fill")
                            .font(.cfFootnote.weight(.bold)).foregroundStyle(Color(hex: 0xF76707))
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                if summary.points > 0 || summary.synced {
                    HStack(spacing: Space.s) {
                        chip(Text("\(CoteCULT.format(summary.points)) pts").monospacedDigit(), tint: Color(hex: 0xF76707))
                        if summary.synced { chip(Text("+\(summary.xp ?? 0) XP").monospacedDigit(), tint: .brand) }
                        if let seeds = summary.seeds, seeds > 0 {
                            chip(SeedsAmount(amount: seeds, signed: true, color: .correct), tint: .correct)
                        }
                        Spacer()
                    }
                }
                if summary.synced, let sessionId, (summary.seeds ?? 0) > 0 {
                    DoubleSeedsButton(ref: "play:\(sessionId.uuidString.lowercased())")
                }
                if !summary.ranked {
                    Label(config.mode == .errors
                          ? "Révision : ton Elo ne bouge pas. Chaque erreur corrigée revient plus tard pour vérifier qu'elle est acquise."
                          : "Entraînement libre : ton Elo ne change pas. Tes erreurs sont notées pour que tu les retravailles.",
                          systemImage: config.mode == .errors ? "arrow.uturn.backward" : "slider.horizontal.3")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                if summary.corrected > 0 {
                    CelebrationCard(kind: .corrected,
                                    title: "\(summary.corrected) erreur\(summary.corrected > 1 ? "s" : "") corrigée\(summary.corrected > 1 ? "s" : "")",
                                    detail: "Elles sortent de ta liste à revoir.")
                }
                if chestsWaiting > 0 {
                    ChestsWaitingCard(tiers: app.progression?.chests.map(\.tier) ?? [], action: onOpenChests)
                }
                if summary.synced, summary.ranked, !summary.ratings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Elo").labelCaps()
                        ForEach(summary.ratings, id: \.domainId) { r in
                            RatingChangeRow(change: r, domainName: app.domainName(r.domainId))
                        }
                        if let r = summary.ratings.first(where: { !$0.placed }) {
                            let left = max(CoteCULT.placementGames - r.placement, 1)
                            Text("Encore \(left) partie\(left > 1 ? "s" : "") classée\(left > 1 ? "s" : "") en \(app.domainName(r.domainId)) pour confirmer ton Elo.")
                                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .popCard()
                } else if summary.syncing {
                    HStack(spacing: Space.s) {
                        ProgressView().controlSize(.small)
                        Text(summary.ranked ? "Calcul de ton Elo et de tes récompenses…" : "Calcul de tes récompenses…")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    .transition(.opacity)
                } else if !summary.synced, summary.total > 0 {
                    Label("Hors ligne : ta partie sera enregistrée dès le retour du réseau.", systemImage: "wifi.slash")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
                if summary.correction != nil || summary.correctionAvailable {
                    CorrectionCard(summary: summary, domainName: { app.domainName($0) }, onCorrect: onCorrect)
                }
                if !summary.missed.isEmpty { learned }
                VStack(spacing: Space.s) {
                    Button(action: onAgain) { Label("Rejouer", systemImage: "arrow.clockwise") }
                        .buttonStyle(InkButtonStyle(fill: accent, text: config.domain.map(DomainPalette.onColor) ?? .white))
                    if showErrors {
                        Button(action: onErrors) { Label("Corriger mes erreurs", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(InkButtonStyle(fill: .paperRaised, text: .ink))
                    }
                    Button(config.domain == nil ? "Terminer" : "Choisir un autre domaine", action: onClose).buttonStyle(.textLink)
                }
                .padding(.top, Space.s)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(Color.paper)
        .overlay {
            if perfect {
                Confetti().ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(Motion.bounce.delay(0.1)) { appeared = true }
            rate >= 0.7 ? Haptics.success() : Haptics.soft()
        }
        .task(id: summary.synced) {
            guard summary.synced else { return }
            await app.refreshProgression()
            withAnimation(Motion.standard) { chestsWaiting = app.progression?.chests.count ?? 0 }
            if !celebrated {
                celebrated = true
                celebrations = moments
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !celebrations.isEmpty }, set: { if !$0 { celebrations = [] } })) {
            CelebrationSequence(items: celebrations) { celebrations = [] }
        }
    }

    /// « Ce que tu as appris » : chaque question ratée avec sa bonne réponse.
    private var learned: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ce que tu as appris").labelCaps()
            ForEach(summary.missed) { question in
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.prompt).font(.cfCallout).foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reveal = question.reveal {
                        if let answer = AnswerText.correct(for: question, answer: reveal.answer) {
                            Label(answer, systemImage: "checkmark.circle.fill")
                                .font(.system(.callout, design: .rounded).weight(.heavy)).foregroundStyle(Color.correct)
                        }
                        Text(reveal.takeaway ?? reveal.explanation).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .lineLimit(3)
                    }
                }
                .popCard(padding: 12, radius: Radius.s)
            }
        }
    }

    /// Domaines dont le placement s'est terminé pendant cette partie : la cote se dévoile.
    /// Les moments forts à fêter en plein écran, dans l'ordre : niveau, Elo confirmé, nouveau rang, trophées.
    private var moments: [Celebration] {
        let chests = app.progression?.chests ?? []
        var items: [Celebration] = []
        if let levelUp {
            let chest = chests.first { $0.source == "level" && $0.ref == "\(levelUp)" } ?? chests.first { $0.source == "level" }
            items.append(.level(levelUp, xp: summary.xp, chest: chest?.tier))
        }
        for r in placementsDone {
            items.append(.rank(CoteCULT.Rank(cote: r.coteAfter), domain: app.domainName(r.domainId), cote: r.coteAfter, confirmed: true))
        }
        for r in rankUps {
            items.append(.rank(CoteCULT.Rank(cote: r.coteAfter), domain: app.domainName(r.domainId), cote: r.coteAfter, confirmed: false))
        }
        let trophyChest = chests.first { $0.source == "trophy" }?.tier
        for name in summary.achievements {
            items.append(.trophy(name: name, detail: nil, chest: trophyChest))
        }
        return items
    }

    private var placementsDone: [PlaySubmitResult.RatingChange] {
        summary.ratings.filter { $0.placed && $0.answered - (summary.answeredByDomain[$0.domainId] ?? 0) < CoteCULT.placementAnswers }
    }

    /// Rang franchi (hors placement tout juste terminé).
    private var rankUps: [PlaySubmitResult.RatingChange] {
        summary.ratings.filter { r in
            r.placed && !placementsDone.contains { $0.domainId == r.domainId }
                && CoteCULT.Rank(cote: r.coteAfter) > CoteCULT.Rank(cote: r.coteBefore)
        }
    }

    private func chip(_ content: some View, tint: Color) -> some View {
        content
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Avant la partie : un vrai écran de lancement, à la couleur du domaine. Le type de partie, le nom du domaine en grand,
/// ce qui va se passer (thèmes, difficulté, effet sur l'Elo) en trois chiffres, puis « Go » avec un compte à rebours 3-2-1
/// (sauté si « Réduire les animations » est activé).
struct PlayIntroView: View {
    let config: PlayConfig
    let domainName: String?
    let count: Int
    var onGo: () -> Void
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var skill: SkillSummary?
    @State private var countdown: Int?

    private var color: Color { config.domain.map(DomainPalette.color) ?? .brand }
    private var onColor: Color { config.domain.map(DomainPalette.onColor) ?? .white }
    private var buttonText: Color { config.domain == nil ? .brandDeep : color }

    var body: some View {
        ZStack {
            Rectangle().fill(config.domain == nil ? AnyShapeStyle(Color.popGradient) : AnyShapeStyle(color)).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: Space.l)
                VStack(alignment: .leading, spacing: Space.m) {
                    Text(domainName ?? config.title)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .tracking(-1.5)
                        .foregroundStyle(onColor)
                        .lineLimit(2).minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: appeared ? 0 : 24)
                    Text(promise)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(onColor.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: appeared ? 0 : 16)
                    if !themeNames.isEmpty { themes }
                }
                Spacer(minLength: Space.l)
                facts
                    .padding(.bottom, Space.l)
                Button(action: go) {
                    Text("Go").frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButtonStyle(fill: .white, text: buttonText, arrow: true))
                .disabled(countdown != nil)
            }
            .padding(Space.gutter)
            .opacity(appeared ? (countdown == nil ? 1 : 0.15) : 0)
            .blur(radius: countdown == nil ? 0 : 6)

            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 180, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(onColor)
                    .id(countdown)
                    .transition(.asymmetric(insertion: .scale(scale: 1.6).combined(with: .opacity),
                                            removal: .scale(scale: 0.6).combined(with: .opacity)))
                    .accessibilityLabel("\(countdown)")
            }
        }
        .onAppear { withAnimation(Motion.moment) { appeared = true } }
        .task {
            guard let domain = config.domain else { return }
            skill = (try? await app.service.skills())?.first { $0.domainId == domain }
        }
    }

    // MARK: Blocs

    private var topBar: some View {
        HStack {
            Label(config.title, systemImage: modeSymbol)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(onColor)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(onColor.opacity(0.45), lineWidth: 1.5))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(onColor)
                    .frame(width: 34, height: 34)
                    .background(onColor.opacity(0.18), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer")
        }
    }

    private var themes: some View {
        FlowLayout(spacing: 6) {
            ForEach(themeNames, id: \.self) { name in
                Text(name)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(onColor)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(onColor.opacity(0.16), in: Capsule())
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    /// Trois repères : nombre de questions, difficulté, enjeu (Elo, placement ou « sans effet »).
    private var facts: some View {
        HStack(alignment: .top, spacing: 0) {
            fact(value: "\(count)", label: count > 1 ? "questions" : "question")
            separator
            fact(value: difficultyValue, label: config.timer.map { "\($0) s par question" } ?? "difficulté")
            separator
            fact(value: stakeValue, label: stakeLabel)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .top) { Rectangle().fill(onColor.opacity(0.3)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(onColor.opacity(0.3)).frame(height: 1) }
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .combine)
    }

    private func fact(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(onColor)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(onColor.opacity(0.75))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle().fill(onColor.opacity(0.3)).frame(width: 1, height: 40).padding(.horizontal, Space.s)
    }

    // MARK: Textes

    private var modeSymbol: String {
        switch config.mode {
        case .quick: return "bolt.fill"
        case .errors: return "arrow.uturn.backward"
        case .training: return config.countsForElo ? "chart.line.uptrend.xyaxis" : "slider.horizontal.3"
        case .surprise, .challenge: return "sparkles"
        }
    }

    /// Une phrase qui dit ce qui attend le joueur.
    private var promise: String {
        switch config.mode {
        case .quick, .surprise, .challenge: return "Un domaine différent à chaque question. De quoi voir large."
        case .errors: return "Les questions qui t'ont échappé reviennent. Cette fois, c'est la bonne."
        case .training:
            if config.countsForElo { return "Tous les thèmes du domaine, à la limite de ton niveau." }
            return config.subdomains.isEmpty ? "Tous les thèmes du domaine, à ton rythme." : "Les thèmes que tu as choisis, à ton rythme."
        }
    }

    private var themeNames: [String] {
        guard let domain = config.domain, !config.subdomains.isEmpty else { return [] }
        let names = Dictionary(uniqueKeysWithValues: app.subdomains(of: domain).map { ($0.id, $0.name) })
        return config.subdomains.compactMap { names[$0] }
    }

    private var difficultyValue: String {
        if config.mode == .errors { return "Tes erreurs" }
        return config.countsForElo || config.mode == .quick ? "Adaptée" : PlayLevelText.name(config.level)
    }

    private var stakeValue: String {
        guard config.countsForElo else { return "Libre" }
        guard let rating = skill?.rating else { return "Elo" }
        return rating.formatted
    }

    private var stakeLabel: String {
        guard config.countsForElo else { return "sans effet sur l'Elo" }
        guard let rating = skill?.rating else { return config.domain == nil ? "en jeu, par domaine" : "en jeu" }
        return rating.placed ? "Elo en jeu · \(rating.rank.name)" : "Elo \(rating.provisionalLabel)"
    }

    // MARK: Lancement

    private func go() {
        guard countdown == nil else { return }
        guard !reduceMotion else { Haptics.soft(); onGo(); return }
        Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                Haptics.soft()
                withAnimation(Motion.press) { countdown = n }
                try? await Task.sleep(nanoseconds: 520_000_000)
            }
            Haptics.success()
            onGo()
        }
    }
}

/// Anneau de chrono : se vide jusqu'à l'échéance, vire au rouge sur les 5 dernières secondes.
struct TimerRing: View {
    let deadline: Date
    let total: TimeInterval
    var color: Color = .brand

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let left = max(0, deadline.timeIntervalSince(timeline.date))
            let urgent = left <= 5
            ZStack {
                Circle().stroke((urgent ? Color.wrong : color).opacity(0.18), lineWidth: 4)
                Circle().trim(from: 0, to: left / total)
                    .stroke(urgent ? Color.wrong : color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(left.rounded(.up)))")
                    .font(.system(.caption, design: .rounded).weight(.heavy)).monospacedDigit()
                    .foregroundStyle(urgent ? Color.wrong : Color.ink)
            }
            .frame(width: 34, height: 34)
            .accessibilityElement()
            .accessibilityLabel("\(Int(left.rounded(.up))) secondes restantes")
        }
    }
}

/// Ligne de cote d'un domaine après une partie : « Histoire   1 342  +18 · Érudit », ou « provisoire ■■□□□ ».
struct RatingChangeRow: View {
    let change: PlaySubmitResult.RatingChange
    let domainName: String

    var body: some View {
        HStack(spacing: Space.s) {
            DomainTag(domainId: change.domainId, name: domainName)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 6) {
                    Text(CoteCULT.format(change.coteAfter)).foregroundStyle(change.placed ? Color.ink : Color.inkSoft)
                    Text(CoteCULT.formatDelta(change.delta))
                        .foregroundStyle(change.delta > 0 ? Color.correct : change.delta < 0 ? Color.wrong : Color.inkSoft)
                }
                .font(.system(.body, design: .rounded).weight(.heavy).monospacedDigit())
                if change.placed {
                    Text(CoteCULT.Rank(cote: change.coteAfter).name).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                } else {
                    HStack(spacing: 6) {
                        Text("provisoire").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                        PlacementSquares(done: change.placement, color: DomainPalette.color(change.domainId), size: 8)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Cinq petits carrés : un par partie classée. Pleins, l'Elo du domaine est confirmé et son niveau se dévoile.
struct PlacementSquares: View {
    let done: Int
    var color: Color = .brand
    var empty: Color? = nil
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< CoteCULT.placementGames, id: \.self) { i in
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(i < done ? color : (empty ?? color.opacity(0.2)))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Fin de partie : « Corrige tes erreurs ». Carte intégrée au bilan, jamais imposée. Les questions ratées se rejouent
/// une fois ; en partie classée, chaque bonne réponse annule l'Elo que l'erreur avait fait perdre (sans jamais en gagner).
private struct CorrectionCard: View {
    let summary: PlaySessionModel.PlaySummary
    let domainName: (String) -> String
    let onCorrect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                Image(systemName: summary.correction == nil ? "arrow.counterclockwise.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(summary.correction == nil ? Color.brand : Color.correct)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.cfHeadline).foregroundStyle(Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if summary.correction == nil {
                Button(action: onCorrect) {
                    HStack(spacing: 8) {
                        if summary.correctionLoading { ProgressView().controlSize(.small) }
                        Label("Corriger mes erreurs", systemImage: "play.rectangle.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.ink)
                .disabled(summary.correctionLoading)
            }
            if let error = summary.correctionError {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
            }
        }
        .popCard()
        .accessibilityElement(children: .contain)
    }

    private var errors: Int { summary.missed.count }

    private var title: String {
        guard let result = summary.correction else {
            return "Corrige tes \(errors) erreur\(errors > 1 ? "s" : "")"
        }
        return result.corrected == result.total ? "\(result.corrected)/\(result.total) corrigées, bravo !"
                                                : "\(result.corrected)/\(result.total) corrigée\(result.corrected > 1 ? "s" : "")"
    }

    private var detail: String {
        guard let result = summary.correction else {
            return summary.ranked
                ? "Après une courte pub, rejoue les questions ratées : chaque bonne réponse annule l'Elo que l'erreur t'a fait perdre."
                : "Après une courte pub, rejoue les questions ratées pour les retenir."
        }
        let refunds = result.refunds.filter { $0.coteRefund > 0 }
        if refunds.isEmpty {
            return result.corrected > 0 ? "Elles restent dans « Mes erreurs » pour une vraie révision demain." : "Elles reviendront dans « Mes erreurs »."
        }
        return refunds.map { "\(domainName($0.domainId)) : +\($0.coteRefund) d'Elo récupérés (\(CoteCULT.format($0.coteAfter)))" }
            .joined(separator: " · ")
    }
}
