import SwiftUI
import CultFiveCore

struct PlaySessionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PlaySessionModel?
    /// Réglages de la partie en cours (« Rejouer » et « Mes erreurs » enchaînent sans refermer l'écran).
    @State private var config: PlayConfig

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
                                           seeds: app.profile?.seeds)
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
                    difficulty: model.currentDifficulty,
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
            PlaySummaryView(config: config, summary: summary,
                            onAgain: { restart(config.again()) },
                            showErrors: config.mode != .errors && ((app.profile?.activeErrors ?? 0) > 0 || summary.correct < summary.total),
                            onErrors: { restart(PlayConfig(mode: .errors)) },
                            onClose: { close() })
        }
    }

    private var accent: Color {
        config.domain.map(DomainPalette.color) ?? .brand
    }

    private func accent(for model: PlaySessionModel) -> Color {
        model.current.map { DomainPalette.color($0.domainId) } ?? accent
    }

    private func restart(_ next: PlayConfig) {
        model = nil
        config = next
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
            Menu {
                Button("Terminer la partie") { Task { await model.finish() } }
                Button("Quitter sans enregistrer", role: .destructive) { close() }
            } label: {
                CloseCircle()
            }
            .accessibilityLabel("Options de partie")
        }
    }

    @ViewBuilder
    private func helpBar(_ model: PlaySessionModel, question: Question) -> some View {
        let helps = model.availableHelps(for: question)
        VStack(alignment: .leading, spacing: Space.s) {
            if let text = model.helpText {
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Color(hex: 0xFFB020)).accessibilityHidden(true)
                    Text(text).font(.cfCallout).foregroundStyle(Color.ink)
                }
                .popCard(padding: 12, radius: Radius.s)
            }
            if !helps.isEmpty {
                HStack(spacing: Space.m) {
                    ForEach(helps, id: \.self) { kind in
                        Button {
                            Task { await model.useHelp(kind) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(title(kind))
                                SeedsAmount(amount: kind.cost, color: .inkSoft)
                            }
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Color.paperRaised, in: Capsule())
                            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.08), radius: 6, y: 3)
                        }
                        .buttonStyle(.row)
                        .foregroundStyle(Color.ink)
                        .disabled((model.seedsBalance ?? 0) < kind.cost)
                    }
                    Spacer()
                }
            }
            if let error = model.helpError {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private func title(_ kind: HelpKind) -> String {
        switch kind {
        case .fiftyFifty: return "50/50"
        case .hint: return "Indice"
        case .context: return "Contexte"
        }
    }

    private func close() {
        Task {
            await app.refreshProfile()
            await app.syncPending()
        }
        dismiss()
    }
}

struct PlaySummaryView: View {
    let config: PlayConfig
    let summary: PlaySessionModel.PlaySummary
    var onAgain: () -> Void
    var showErrors = false
    var onErrors: () -> Void = {}
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @State private var appeared = false

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
                if !summary.ranked {
                    Label("Entraînement libre : ton niveau ne change pas. Tes erreurs sont notées pour que tu les retravailles.",
                          systemImage: "slider.horizontal.3")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                if summary.corrected > 0 {
                    CelebrationCard(kind: .corrected,
                                    title: "\(summary.corrected) erreur\(summary.corrected > 1 ? "s" : "") corrigée\(summary.corrected > 1 ? "s" : "")",
                                    detail: "Elles sortent de ta liste à revoir.")
                }
                if let levelUp {
                    CelebrationCard(kind: .levelUp, title: "Niveau \(levelUp)", detail: "Ton XP grimpe, continue comme ça.")
                }
                ForEach(summary.achievements, id: \.self) { name in
                    CelebrationCard(kind: .trophy, title: name)
                }
                ForEach(placementsDone, id: \.domainId) { r in
                    CelebrationCard(kind: .rating, title: "Placement terminé : \(CoteCULT.format(r.coteAfter))",
                                    detail: "\(app.domainName(r.domainId)) · rang \(CoteCULT.Rank(cote: r.coteAfter).name). Ton Elo bouge maintenant à chaque partie classée.")
                }
                ForEach(rankUps, id: \.domainId) { r in
                    CelebrationCard(kind: .rating, title: "Nouveau rang : \(CoteCULT.Rank(cote: r.coteAfter).name)",
                                    detail: "\(app.domainName(r.domainId)) · \(CoteCULT.format(r.coteAfter))")
                }
                if summary.synced, summary.ranked, !summary.ratings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Elo").labelCaps()
                        ForEach(summary.ratings, id: \.domainId) { r in
                            RatingChangeRow(change: r, domainName: app.domainName(r.domainId))
                        }
                    }
                    .popCard()
                } else if !summary.synced, summary.total > 0 {
                    Label("Hors ligne : ta partie sera enregistrée dès le retour du réseau.", systemImage: "wifi.slash")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
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
            if perfect || levelUp != nil || !summary.achievements.isEmpty || !placementsDone.isEmpty || !rankUps.isEmpty {
                Confetti().ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(Motion.bounce.delay(0.1)) { appeared = true }
            rate >= 0.7 ? Haptics.success() : Haptics.soft()
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

/// Annonce de la partie : domaine, type (classée / entraînement), réglages. Un temps pour se concentrer.
struct PlayIntroView: View {
    let config: PlayConfig
    let domainName: String?
    let count: Int
    var onGo: () -> Void
    var onClose: () -> Void

    @State private var appeared = false

    private var color: Color { config.domain.map(DomainPalette.color) ?? .brand }
    private var onColor: Color { config.domain.map(DomainPalette.onColor) ?? .white }

    var body: some View {
        ZStack {
            Rectangle().fill(config.domain == nil ? AnyShapeStyle(Color.popGradient) : AnyShapeStyle(color)).ignoresSafeArea()
            if let domain = config.domain {
                Image(systemName: DomainPalette.symbol(domain))
                    .font(.system(size: 260, weight: .black))
                    .foregroundStyle(onColor.opacity(0.1))
                    .rotationEffect(.degrees(-14))
                    .offset(x: 110, y: -170)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
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
                Spacer()
                Text(config.title.uppercased()).font(.cfLabel).tracking(1).foregroundStyle(onColor.opacity(0.8))
                Text(domainName ?? config.title)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(onColor)
                    .minimumScaleFactor(0.6).lineLimit(2)
                VStack(alignment: .leading, spacing: 8) {
                    line(icon: "number", "\(count) question\(count > 1 ? "s" : "")")
                    if config.mode == .training {
                        line(icon: config.ranked ? "chart.line.uptrend.xyaxis" : "slider.horizontal.3",
                             config.ranked ? "Adaptée à ton niveau · compte pour ta progression" : "Difficulté : \(PlayLevelText.name(config.level)) · sans effet sur ton niveau")
                    }
                    if let timer = config.timer { line(icon: "stopwatch.fill", "\(timer) secondes par question") }
                    if !config.subdomains.isEmpty { line(icon: "square.grid.2x2.fill", "\(config.subdomains.count) thème\(config.subdomains.count > 1 ? "s" : "") choisi\(config.subdomains.count > 1 ? "s" : "")") }
                }
                Spacer()
                Button("Go !", action: onGo)
                    .buttonStyle(InkButtonStyle(fill: .white, text: config.domain == nil ? Color(hex: 0x3A1FB8) : color))
            }
            .padding(Space.gutter)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .onAppear { withAnimation(Motion.moment) { appeared = true } }
    }

    private func line(icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(.callout, design: .rounded).weight(.bold))
            .foregroundStyle(onColor.opacity(0.9))
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

/// Ligne de cote d'un domaine après une partie : « Histoire   1 342  +18 · Érudit », ou « Placement 2/5 ».
struct RatingChangeRow: View {
    let change: PlaySubmitResult.RatingChange
    let domainName: String

    var body: some View {
        HStack(spacing: Space.s) {
            DomainTag(domainId: change.domainId, name: domainName)
            Spacer()
            if change.placed {
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(CoteCULT.format(change.coteAfter)).foregroundStyle(Color.ink)
                        Text(CoteCULT.formatDelta(change.delta))
                            .foregroundStyle(change.delta > 0 ? Color.correct : change.delta < 0 ? Color.wrong : Color.inkSoft)
                    }
                    .font(.system(.body, design: .rounded).weight(.heavy).monospacedDigit())
                    Text(CoteCULT.Rank(cote: change.coteAfter).name).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                }
            } else {
                PlacementDots(done: change.placement, color: DomainPalette.color(change.domainId))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// « Placement ●●○○○ 2/5 » : parties de placement jouées avant que la cote ne se dévoile.
struct PlacementDots: View {
    let done: Int
    var color: Color = .brand
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            if !compact { Text("Placement").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft) }
            HStack(spacing: 3) {
                ForEach(0 ..< CoteCULT.placementGames, id: \.self) { i in
                    Circle().fill(i < done ? color : color.opacity(0.2)).frame(width: 7, height: 7)
                }
            }
            Text("\(done)/\(CoteCULT.placementGames)").font(.system(.footnote, design: .rounded).weight(.heavy)).monospacedDigit()
                .foregroundStyle(Color.inkSoft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Placement : \(done) partie\(done > 1 ? "s" : "") sur \(CoteCULT.placementGames)")
    }
}
