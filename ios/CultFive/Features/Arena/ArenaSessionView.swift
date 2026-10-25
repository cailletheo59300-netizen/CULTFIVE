import SwiftUI
import CultFiveCore

// Duel classé (D-111) : « Trouver un adversaire » prend le plus ancien duel ouvert d'un autre joueur (on l'affronte
// côte à côte, ses réponses se dévoilent après les nôtres) ; s'il n'y en a pas, on ouvre un duel à l'Arène que le
// prochain joueur prendra. 7 questions, 15 s chacune, chrono tenu par le serveur. Jamais d'écran d'attente.

@MainActor
@Observable
final class ArenaSessionModel {
    enum Stage: Equatable {
        case searching
        /// Adversaire trouvé (ou duel ouvert à l'Arène) : l'écran avant la 1re question.
        case ready
        case question
        case loading
        case result(ArenaDuelResult)
        case failed(String)
    }

    /// Une case de la piste de scores : à jouer, juste, faux.
    enum Mark: Equatable { case pending, correct, wrong }

    private(set) var stage: Stage = .searching
    private(set) var match: ArenaMatch?
    private(set) var question: Question?
    private(set) var phase: AnswerPhase = .answering
    private(set) var position = 0
    private(set) var deadline: Date?
    private(set) var isRetrying = false
    private(set) var mine: [Mark] = []
    private(set) var theirs: [Mark] = []
    /// Temps de l'adversaire sur la question en cours, s'il y a déjà répondu (pas sa réponse).
    private(set) var themMs: Int?
    /// Ce qu'il a fait sur la question qu'on vient de corriger.
    private(set) var lastThem: ArenaVerdict.Them?

    private let service: GameService
    private var stopwatch = Stopwatch()
    private var pending: (given: GivenAnswer?, ms: Int?)?
    private var advancing = false
    private var countedDuel: UUID?

    var duel: ArenaDuel? { match?.duel }
    var total: Int { duel?.total ?? 7 }
    var seconds: Int { duel?.seconds ?? 15 }
    var opponent: ArenaDuel.Opponent? { duel?.opponent }
    var myScore: Int { mine.filter { $0 == .correct }.count }
    var theirScore: Int { theirs.filter { $0 == .correct }.count }

    init(service: GameService) {
        self.service = service
    }

    /// Recherche : au moins un court instant d'animation, même quand le serveur répond tout de suite.
    func find() async {
        stage = .searching
        question = nil
        lastThem = nil
        let started = Date()
        do {
            let found = try await service.arenaFind()
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 1.6 { try? await Task.sleep(nanoseconds: UInt64((1.6 - elapsed) * 1_000_000_000)) }
            match = found
            position = found.duel.me.answered
            mine = Array(repeating: .pending, count: found.duel.total)
            theirs = Array(repeating: .pending, count: found.duel.total)
            if found.resumed && position > 0 {
                await load()
            } else {
                Haptics.success()
                stage = .ready
            }
        } catch {
            stage = .failed(error.userMessage ?? "Impossible de trouver un duel. Réessaie.")
        }
    }

    func begin() async { await load() }

    private func load() async {
        guard let duel else { return }
        guard position < duel.total else { await showResult(); return }
        do {
            let response = try await service.arenaQuestion(duel: duel.id, position: position + 1)
            guard let next = response.question else { await showResult(); return }
            position = next.position ?? position + 1
            question = next
            themMs = response.themMs
            lastThem = nil
            phase = .answering
            deadline = nil
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed(error.userMessage ?? "Question indisponible. Réessaie.")
        }
    }

    /// La question est affichée : les deux chronos démarrent.
    func questionDisplayed() {
        guard phase.isAnswering, deadline == nil else { return }
        stopwatch.start()
        deadline = Date().addingTimeInterval(TimeInterval(seconds))
    }

    func submit(_ given: GivenAnswer) { send(given) }

    /// Temps écoulé : faux.
    func timeUp() { send(nil) }

    private func send(_ given: GivenAnswer?) {
        guard phase.isAnswering, let duel else { return }
        stopwatch.pause()
        deadline = nil
        let ms = stopwatch.elapsedMilliseconds
        pending = (given, ms)
        phase = .submitting(given)
        Task { await post(duel: duel.id, given: given, ms: ms) }
    }

    func retry() {
        guard let duel, let pending else { return }
        isRetrying = false
        Task { await post(duel: duel.id, given: pending.given, ms: pending.ms) }
    }

    private func post(duel: UUID, given: GivenAnswer?, ms: Int?) async {
        do {
            let verdict = try await service.arenaAnswer(duel: duel, position: position, given: given, clientMs: ms)
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            Feedback.answer(correct)
            let index = position - 1
            if mine.indices.contains(index) { mine[index] = correct ? .correct : .wrong }
            if let them = verdict.them, theirs.indices.contains(index) {
                theirs[index] = (them.isCorrect ?? false) ? .correct : .wrong
                lastThem = them
            }
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pending = nil
        } catch let error as BackendError where ["duel_closed", "duel_not_served", "duel_not_found"].contains(error.code ?? "") {
            pending = nil
            await showResult()
        } catch {
            isRetrying = true
        }
    }

    func next() async {
        guard !advancing else { return }
        advancing = true
        defer { advancing = false }
        if position >= total { await showResult() } else { await load() }
    }

    func showResult() async {
        guard let duel else { return }
        stage = .loading
        do {
            let result = try await service.arenaResult(duel.id)
            stage = .result(result)
        } catch {
            stage = .failed(error.userMessage ?? "Bilan indisponible. Réessaie.")
        }
    }

    /// Vrai une seule fois par duel : à appeler quand le bilan s'affiche (pub entre les parties).
    func takeGameCount() -> Bool {
        guard let id = duel?.id, countedDuel != id else { return false }
        countedDuel = id
        return true
    }
}

/// Duel classé en plein écran.
struct ArenaSessionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: ArenaSessionModel?

    var body: some View {
        ZStack {
            if let model { content(model) } else { ArenaPalette.night.ignoresSafeArea() }
        }
        .task {
            guard model == nil else { return }
            let session = ArenaSessionModel(service: app.service)
            model = session
            await session.find()
        }
    }

    @ViewBuilder
    private func content(_ model: ArenaSessionModel) -> some View {
        switch model.stage {
        case .searching:
            ArenaSearchingView { dismiss() }
                .transition(.opacity)
        case .ready:
            ArenaReadyView(model: model, me: app.profile?.handle ?? "Toi", onClose: { dismiss() }) {
                Task { await model.begin() }
            }
            .transition(.opacity)
        case .loading:
            ZStack { ArenaPalette.night.ignoresSafeArea(); ProgressView().tint(.white) }
        case .failed(let message):
            ZStack {
                ArenaPalette.night.ignoresSafeArea()
                VStack(spacing: Space.l) {
                    ArenaCrest().frame(width: 110)
                    Text(message).font(.cfHeadline).foregroundStyle(.white).multilineTextAlignment(.center)
                    Button("Réessayer") { Task { await model.find() } }.buttonStyle(.sun)
                    Button("Fermer") { dismiss() }.buttonStyle(TextLinkStyle(color: .white))
                }
                .padding(Space.gutter)
            }
        case .question:
            if let question = model.question {
                VStack(spacing: 0) {
                    ArenaScoreboard(model: model, me: app.profile?.handle ?? "Toi")
                    QuestionScreen(
                        question: question,
                        domainName: app.domainName(question.domainId),
                        phase: model.phase,
                        continueTitle: model.position >= model.total ? "Voir le résultat" : "Question suivante",
                        onSubmit: { model.submit($0) },
                        onContinue: { Task { await model.next() } },
                        onDisplayed: { model.questionDisplayed() }
                    ) {
                        if let deadline = model.deadline {
                            TimerRing(deadline: deadline, total: TimeInterval(model.seconds), color: ArenaPalette.me)
                        }
                    }
                }
                .background(Color.paper.ignoresSafeArea())
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .task(id: model.deadline) {
                    guard let deadline = model.deadline else { return }
                    try? await Task.sleep(nanoseconds: UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000))
                    guard !Task.isCancelled, model.deadline == deadline else { return }
                    model.timeUp()
                }
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
        case .result(let result):
            ArenaResultView(result: result, me: app.profile?.handle ?? "Toi",
                            onNext: { leave { await model.find() } },
                            onClose: { leave { dismiss() } })
                .transition(.opacity)
                .task {
                    if model.takeGameCount() { app.noteGameFinished() }
                    if result.duel.isWaiting { app.askNotificationsAfterSocial() }
                }
        }
    }

    /// Sortie du bilan : la pub entre les parties peut passer, puis l'action ; les coffres gagnés s'ouvrent ensuite.
    private func leave(_ then: @escaping () async -> Void) {
        Task {
            await app.interstitialBetweenGames()
            await then()
            await app.refreshProfile()
            await app.refreshProgression()
        }
    }
}

// MARK: - Recherche

/// « Recherche d'un adversaire » : le blason respire, des cercles s'élargissent autour.
private struct ArenaSearchingView: View {
    let onClose: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ArenaPalette.night.ignoresSafeArea()
            VStack(spacing: Space.l) {
                HStack {
                    Spacer()
                    Button(action: onClose) { CloseCircle() }.accessibilityLabel("Fermer")
                }
                Spacer()
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2)
                            .frame(width: 170, height: 170)
                            .scaleEffect(pulse ? 1.9 : 0.8)
                            .opacity(pulse ? 0 : 1)
                            .animation(reduceMotion ? nil : .easeOut(duration: 2.1).repeatForever(autoreverses: false).delay(Double(i) * 0.7),
                                       value: pulse)
                    }
                    ArenaCrest()
                        .frame(width: 150)
                        .scaleEffect(pulse ? 1.04 : 0.97)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                }
                .frame(height: 260)
                Text("Recherche d'un adversaire…")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("7 questions mélangées · 15 s chacune")
                    .font(.cfFootnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Spacer()
            }
            .padding(Space.gutter)
        }
        .onAppear { pulse = true }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Avant la 1re question

/// Adversaire trouvé (face à face) ou duel ouvert à l'Arène (on joue d'abord, le prochain joueur t'affronte).
private struct ArenaReadyView: View {
    let model: ArenaSessionModel
    let me: String
    let onClose: () -> Void
    let onStart: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            ArenaPalette.night.ignoresSafeArea()
            VStack(spacing: Space.l) {
                HStack {
                    Spacer()
                    Button(action: onClose) { CloseCircle() }.accessibilityLabel("Fermer")
                }
                Text(model.match?.matched == true ? "Adversaire trouvé" : "Duel lancé")
                    .labelCaps(Color.sun)
                faceOff
                rules
                Spacer()
                Button(action: onStart) {
                    Text("C'est parti")
                }
                .buttonStyle(.sun)
            }
            .padding(Space.gutter)
        }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { shown = true } }
    }

    private var faceOff: some View {
        HStack(alignment: .center, spacing: 0) {
            player(handle: me, detail: "Toi", me: true)
                .offset(x: shown ? 0 : -160)
            Text("VS")
                .font(.system(size: 34, weight: .black, design: .rounded)).italic()
                .foregroundStyle(Color.sun)
                .scaleEffect(shown ? 1 : 2.2)
                .opacity(shown ? 1 : 0)
                .frame(width: 70)
            if let opponent = model.opponent {
                player(handle: opponent.handle, detail: "\(opponent.weekPoints) pts cette semaine", me: false,
                       champion: opponent.champion)
                    .offset(x: shown ? 0 : 160)
            } else {
                mystery.offset(x: shown ? 0 : 160)
            }
        }
        .padding(.top, Space.l)
    }

    private func player(handle: String, detail: String, me: Bool, champion: Bool = false) -> some View {
        VStack(spacing: 8) {
            ArenaAvatar(handle: handle, size: 92, ring: me ? Color.sun : .white, me: me)
                .overlay(alignment: .top) {
                    if champion { ArenaCrown(size: 34).offset(y: -26) }
                }
            Text(handle).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pas encore d'adversaire : une place en pointillés.
    private var mystery: some View {
        VStack(spacing: 8) {
            Circle()
                .strokeBorder(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [7, 6]))
                .overlay(Text("?").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.8)))
                .frame(width: 92, height: 92)
            Text("Ton adversaire").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
            Text("le prochain à lancer un duel").font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.match?.matched == true, let opponent = model.opponent {
                rule("person.fill.checkmark", "\(opponent.handle) a déjà joué ces questions : tu vois ses réponses après les tiennes")
            } else {
                rule("bolt.fill", "Tu joues maintenant. Ton duel est ouvert à toute l'Arène : le premier joueur qui lance un duel classé t'affronte")
            }
            rule("timer", "\(model.total) questions, \(model.seconds) s chacune")
            rule("plus.circle.fill", "Victoire +3 pts · égalité +1 · défaite 0, tu ne perds jamais de points")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.bold)).foregroundStyle(Color.sun).frame(width: 24)
            Text(text).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Piste des scores

/// En haut de chaque question : toi et ton adversaire, score et une case par question (verte, rouge, à jouer).
struct ArenaScoreboard: View {
    let model: ArenaSessionModel
    let me: String

    var body: some View {
        VStack(spacing: 8) {
            lane(handle: me, score: model.myScore, marks: model.mine, color: ArenaPalette.me, me: true)
            lane(handle: model.opponent?.handle ?? "Ton adversaire", score: model.opponent == nil ? nil : model.theirScore,
                 marks: model.theirs, color: ArenaPalette.them, me: false)
            status
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, 10)
        .background(Color.paperRaised.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }

    private func lane(handle: String, score: Int?, marks: [ArenaSessionModel.Mark], color: Color, me: Bool) -> some View {
        HStack(spacing: 10) {
            if me || model.opponent != nil {
                ArenaAvatar(handle: handle, size: 28, me: me)
            } else {
                Circle().strokeBorder(Color.inkSoft.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .frame(width: 28, height: 28)
            }
            Text(me ? "Toi" : handle)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(Color.ink).lineLimit(1)
                .frame(width: 92, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fill(mark, current: index == model.position - 1 && me, color: color))
                        .frame(height: 8)
                }
            }
            Text(score.map(String.init) ?? "–")
                .font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(me ? color : Color.ink)
                .frame(width: 24, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(Motion.standard, value: score)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(me ? "Toi" : handle) : \(score ?? 0) bonnes réponses")
    }

    private func fill(_ mark: ArenaSessionModel.Mark, current: Bool, color: Color) -> Color {
        switch mark {
        case .correct: return .correct
        case .wrong: return .wrong
        case .pending: return current ? color.opacity(0.55) : Color.hairline
        }
    }

    /// Ce que l'adversaire a fait sur cette question : son temps avant, sa réponse après.
    @ViewBuilder private var status: some View {
        if let opponent = model.opponent {
            if let them = model.lastThem {
                statusLine(them.isCorrect == true ? "\(opponent.handle) avait juste" : "\(opponent.handle) s'était trompé",
                           ms: them.countedMs, good: them.isCorrect == true)
            } else if model.phase.isAnswering, let ms = model.themMs {
                statusLine("\(opponent.handle) a répondu en", ms: ms, good: nil)
            }
        }
    }

    private func statusLine(_ text: String, ms: Int?, good: Bool?) -> some View {
        HStack(spacing: 6) {
            Circle().fill(good.map { $0 ? Color.correct : Color.wrong } ?? ArenaPalette.them).frame(width: 7, height: 7)
            Text(text).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkSoft)
            if let ms {
                Text(String(format: "%.1f s", Double(ms) / 1000))
                    .font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(Color.ink)
            }
            Spacer()
        }
        .transition(.opacity)
    }
}
