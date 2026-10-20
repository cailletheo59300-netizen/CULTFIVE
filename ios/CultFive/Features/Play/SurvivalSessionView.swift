import SwiftUI
import StoreKit
import CultFiveCore

// Mode Survie (D-072) : on répond jusqu'à la première erreur. Le serveur sert une question à la fois sans sa réponse
// et juge chaque réponse (comme le 5 du jour) ; 20 s par question, de plus en plus dur, hors Elo.

@MainActor
@Observable
final class SurvivalSessionModel {
    enum Stage: Equatable {
        case intro
        case loading
        case question
        case result(SurvivalResult)
        case failed(String)
    }

    private(set) var stage: Stage = .intro
    private(set) var question: Question?
    private(set) var phase: AnswerPhase = .answering
    private(set) var score = 0
    private(set) var record: Int
    private(set) var seconds: Int
    private(set) var position = 0
    private(set) var deadline: Date?
    private(set) var isRetrying = false
    private(set) var finished = false

    private let service: GameService
    /// nil : tous domaines.
    let domain: String?
    private var runId: UUID?
    private var stopwatch = Stopwatch()
    private var pending: (given: GivenAnswer?, ms: Int?)?
    /// Passage à la question suivante en cours : un double appui ne doit pas la demander deux fois.
    private var advancing = false

    init(service: GameService, domain: String?, overview: SurvivalOverview?) {
        self.service = service
        self.domain = domain
        record = overview?.record ?? 0
        seconds = overview?.seconds ?? 20
    }

    /// Record du domaine, quand l'écran s'ouvre depuis la fiche d'un domaine.
    func loadRecord() async {
        guard let overview = try? await service.survivalOverview(domain: domain) else { return }
        record = overview.record
        seconds = overview.seconds
    }

    func start() async {
        stage = .loading
        score = 0
        position = 0
        finished = false
        do {
            let start = try await service.survivalStart(domain: domain)
            runId = start.runId
            record = start.record
            seconds = start.seconds
            await load()
        } catch {
            stage = .failed(error.userMessage ?? "Impossible de lancer la partie. Réessaie.")
        }
    }

    private func load() async {
        guard let runId else { return }
        do {
            let response = try await service.survivalQuestion(run: runId, position: position + 1)
            guard let next = response.question else { await showResult(); return }
            // La position vient du serveur : jamais de décalage, même si la question a été redemandée.
            position = next.position ?? position + 1
            question = next
            phase = .answering
            deadline = nil
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed(error.userMessage ?? "Question indisponible. Réessaie.")
        }
    }

    /// La question est affichée : les deux chronos (joueur et 20 s) démarrent.
    func questionDisplayed() {
        guard phase.isAnswering, deadline == nil else { return }
        stopwatch.start()
        deadline = Date().addingTimeInterval(TimeInterval(seconds))
    }

    func submit(_ given: GivenAnswer) { send(given) }

    /// Temps écoulé : la réponse est fausse.
    func timeUp() { send(nil) }

    private func send(_ given: GivenAnswer?) {
        guard phase.isAnswering, let runId else { return }
        stopwatch.pause()
        deadline = nil
        let ms = stopwatch.elapsedMilliseconds
        pending = (given, ms)
        phase = .submitting(given)
        Task { await post(runId: runId, given: given, ms: ms) }
    }

    func retry() {
        guard let runId, let pending else { return }
        isRetrying = false
        Task { await post(runId: runId, given: pending.given, ms: pending.ms) }
    }

    private func post(runId: UUID, given: GivenAnswer?, ms: Int?) async {
        do {
            let verdict = try await service.survivalAnswer(run: runId, position: position, given: given, clientMs: ms)
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            Feedback.answer(correct)
            if correct { score += 1 }
            finished = verdict.finished ?? !correct
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pending = nil
        } catch let error as BackendError where Self.closedCodes.contains(error.code ?? "") {
            // Partie déjà close ou réponse hors de propos : on montre le bilan plutôt que de réessayer sans fin.
            pending = nil
            await showResult()
        } catch {
            isRetrying = true
        }
    }

    private static let closedCodes: Set<String> = ["survival_not_served", "survival_closed", "survival_out_of_order"]

    func next() async {
        guard !advancing, !phase.isAnswering || stage != .question else { return }
        advancing = true
        defer { advancing = false }
        if finished { await showResult() } else { await load() }
    }

    private func showResult() async {
        guard let runId else { return }
        stage = .loading
        do {
            let result = try await service.survivalResult(run: runId)
            record = result.record
            stage = .result(result)
        } catch {
            stage = .failed(error.userMessage ?? "Bilan indisponible. Réessaie.")
        }
    }

    /// Quitter en cours de partie : elle est close (le score compte, comme une erreur).
    func abandon() async {
        guard let runId, case .question = stage else { return }
        _ = try? await service.survivalResult(run: runId)
    }
}

/// Partie de Survie en plein écran : intro, questions, bilan.
struct SurvivalSessionView: View {
    /// nil : tous domaines.
    var domain: String? = nil
    var overview: SurvivalOverview? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var model: SurvivalSessionModel?

    private static let flame = Color(hex: 0xFF6B2C)

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model { content(model) } else { ProgressView() }
        }
        .task {
            if model == nil {
                let session = SurvivalSessionModel(service: app.service, domain: domain, overview: overview)
                model = session
                if overview == nil { await session.loadRecord() }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: SurvivalSessionModel) -> some View {
        switch model.stage {
        case .intro:
            intro(model)
        case .loading:
            ProgressView().tint(Self.flame)
        case .failed(let message):
            VStack(spacing: Space.l) {
                Text(message).font(.cfHeadline).multilineTextAlignment(.center)
                Button("Fermer") { dismiss() }.buttonStyle(.ink)
            }
            .padding(Space.gutter)
        case .question:
            if let question = model.question {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    continueTitle: model.finished ? "Voir mon score" : "Question suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() }
                ) {
                    HStack(spacing: Space.m) {
                        ScoreFlame(score: model.score)
                        if let deadline = model.deadline {
                            TimerRing(deadline: deadline, total: TimeInterval(model.seconds), color: Self.flame)
                        }
                        Button { close(model) } label: { CloseCircle() }
                            .accessibilityLabel("Arrêter la partie")
                    }
                }
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
            resultView(result, model: model)
                .transition(.opacity)
                .task { app.noteGameFinished() }
        }
    }

    // MARK: Écrans

    private func intro(_ model: SurvivalSessionModel) -> some View {
        VStack(spacing: Space.l) {
            HStack {
                Spacer()
                Button { dismiss() } label: { CloseCircle() }.accessibilityLabel("Fermer")
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(Self.flame)
                .frame(width: 120, height: 120)
                .background(Self.flame.opacity(0.14), in: Circle())
            Text("Survie").font(.cfDisplay)
            if let domain {
                DomainTag(domainId: domain, name: app.domainName(domain))
            }
            VStack(alignment: .leading, spacing: 12) {
                rule("xmark.octagon.fill", "Une erreur et c'est fini")
                rule("timer", "\(model.seconds) s par question")
                rule("arrow.up.right", "De plus en plus dur")
            }
            if model.record > 0 {
                Text("Ton record : \(model.record)")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(Self.flame)
            }
            Spacer()
            Button("C'est parti !") { Task { await model.start() } }
                .buttonStyle(.sun)
        }
        .padding(Space.gutter)
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.bold)).foregroundStyle(Self.flame).frame(width: 26)
            Text(text).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
        }
    }

    private func resultView(_ result: SurvivalResult, model: SurvivalSessionModel) -> some View {
        VStack(spacing: Space.l) {
            Spacer()
            if result.newRecord {
                Text("NOUVEAU RECORD")
                    .font(.system(.caption, design: .rounded).weight(.black)).tracking(1)
                    .foregroundStyle(Color(hex: 0x1E1340))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.sun, in: Capsule())
            }
            Image(systemName: "flame.fill").font(.system(size: 44, weight: .black)).foregroundStyle(Self.flame)
            Text("\(result.score)")
                .font(.system(size: 88, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(Color.ink)
            Text(result.score > 1 ? "bonnes réponses d'affilée" : "bonne réponse")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
            HStack(spacing: 10) {
                if !result.newRecord {
                    stat("Record", "\(result.record)")
                }
                if result.reward > 0 {
                    stat("Neurones", "+\(result.reward)")
                }
            }
            Spacer()
            Button("Rejouer") { leave { await model.start() } }
                .buttonStyle(.sun)
            Button("Terminer") { leave { dismiss() } }
                .buttonStyle(.textLink)
        }
        .padding(Space.gutter)
        .onAppear {
            if result.newRecord { Haptics.success() }
        }
        .task {
            // Nouveau record : un bon moment pour la demande de note d'Apple (une fois, joueur actif 3 jours).
            guard result.newRecord, result.score >= 5, ReviewPrompt.isDue else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            ReviewPrompt.markAsked()
            requestReview()
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(Color.ink)
            Text(label).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
        }
        .frame(minWidth: 110)
        .padding(.vertical, 12)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Sortie du bilan : la pub entre les parties peut passer, puis l'action (rejouer ou fermer).
    private func leave(_ then: @escaping () async -> Void) {
        Task {
            await app.interstitialBetweenGames()
            await then()
            await app.refreshProfile()
        }
    }

    private func close(_ model: SurvivalSessionModel) {
        Task {
            await model.abandon()
            await app.refreshProfile()
        }
        dismiss()
    }
}

/// Série en cours : flamme et nombre de bonnes réponses.
private struct ScoreFlame: View {
    let score: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xFF6B2C))
            Text("\(score)").monospacedDigit().foregroundStyle(Color.ink)
        }
        .font(.system(.headline, design: .rounded).weight(.black))
        .contentTransition(.numericText())
        .animation(Motion.standard, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score) bonnes réponses")
    }
}

/// Partie lancée depuis Jouer ou la fiche d'un domaine : Survie ou partie classique.
struct GameCover: View {
    let config: PlayConfig

    var body: some View {
        if config.survival {
            SurvivalSessionView(domain: config.domain)
        } else {
            PlaySessionView(config: config)
        }
    }
}
