import Foundation
import SwiftUI
import CultFiveCore

struct PlayConfig: Identifiable, Hashable {
    let id = UUID()
    var mode: PlayMode
    var domain: String? = nil
    /// Sous-thèmes choisis ; vide = tout le domaine.
    var subdomains: [String] = []
    var count: Int = 10
    /// Partie classée (adaptative, fait bouger le niveau) ou entraînement libre.
    var ranked = true
    var level: PlayLevel = .adaptive
    /// Secondes par question (entraînement libre) ; nil = sans chrono.
    var timer: Int? = nil

    /// L'Elo ne bouge que sur une partie classée couvrant tout le domaine ; jamais en « Mes erreurs » (règle appliquée aussi par le serveur).
    var countsForElo: Bool { ranked && mode != .errors && subdomains.isEmpty }

    var title: String {
        switch mode {
        case .quick: return "Partie rapide"
        case .training: return ranked ? "Partie classée" : "Entraînement libre"
        case .surprise: return "Mix surprise"
        case .errors: return "Mes erreurs"
        case .challenge: return "Défi"
        }
    }

    /// Ligne de réglages affichée à l'intro : « 10 questions · Débutant · 20 s ».
    var settingsLine: String {
        var parts = ["\(count) questions"]
        if !ranked { parts.append(PlayLevelText.name(level)) }
        if let timer { parts.append("\(timer) s par question") }
        return parts.joined(separator: " · ")
    }

    /// Même réglages, nouvelle partie (nouvel identifiant).
    func again() -> PlayConfig {
        PlayConfig(mode: mode, domain: domain, subdomains: subdomains, count: count, ranked: ranked, level: level, timer: timer)
    }
}

enum PlayLevelText {
    static func name(_ level: PlayLevel) -> String {
        switch level {
        case .adaptive: return "Mon niveau"
        case .beginner: return "Débutant"
        case .intermediate: return "Intermédiaire"
        case .expert: return "Expert"
        }
    }
}

/// Partie du mode Jouer. Verdict instantané en local (le pack contient les réponses), synchronisation groupée en fin de partie.
/// Hors-ligne : la partie continue, les tentatives partent en file et sont envoyées au retour du réseau.
@MainActor
@Observable
final class PlaySessionModel {
    enum Stage: Equatable {
        case loading
        /// Écran d'annonce : domaine, type de partie, réglages.
        case intro
        case playing
        case summary(PlaySummary)
        case empty(String)
        case failed(String)
    }

    struct PlaySummary: Equatable {
        var correct: Int
        var total: Int
        var xp: Int?
        var seeds: Int?
        var corrected: Int
        var achievements: [String]
        var synced: Bool
        var ranked = true
        /// Questions ratées, avec leur bonne réponse : « ce que tu as appris ».
        var missed: [Question] = []
        var bestStreak = 0
        /// Points de la partie (serveur ; estimation locale hors ligne).
        var points = 0
        /// Variation de cote par domaine (partie classée synchronisée).
        var ratings: [PlaySubmitResult.RatingChange] = []

        /// Réponses de la partie par domaine (pour savoir si le placement vient de se terminer).
        var answeredByDomain: [String: Int] = [:]

        static func == (lhs: PlaySummary, rhs: PlaySummary) -> Bool {
            lhs.correct == rhs.correct && lhs.total == rhs.total && lhs.xp == rhs.xp && lhs.seeds == rhs.seeds
                && lhs.corrected == rhs.corrected && lhs.synced == rhs.synced
        }
    }

    let config: PlayConfig
    private(set) var stage: Stage = .loading
    private(set) var questions: [Question] = []
    private(set) var index = 0
    private(set) var phase: AnswerPhase = .answering
    private(set) var results: [Bool] = []
    private(set) var removedOptions: Set<String> = []
    private(set) var helpText: String?
    private(set) var seedsBalance: Int?
    private(set) var helpError: String?
    /// Fin du temps imparti pour la question en cours (entraînement chronométré).
    private(set) var deadline: Date?
    /// Points cumulés pendant la partie (même règle que le serveur).
    private(set) var points = 0
    /// Points de la dernière réponse, pour le badge « +140 ».
    private(set) var lastPoints = 0

    private let service: GameService
    private let queue: OfflineAttemptQueue
    private let cache: DiskCache
    private var sessionId: UUID?
    private var attempts: [PlayAttempt] = []
    private var stopwatch = Stopwatch()
    private var usedOfflinePack = false

    init(config: PlayConfig, service: GameService, queue: OfflineAttemptQueue, cache: DiskCache, seeds: Int?) {
        self.config = config
        self.service = service
        self.queue = queue
        self.cache = cache
        self.seedsBalance = seeds
    }

    var current: Question? { questions.indices.contains(index) ? questions[index] : nil }

    /// Difficulté ressentie de la question en cours (packs Jouer, hors mode Erreurs).
    var currentDifficulty: RelativeDifficulty? {
        guard config.mode != .errors, let p = current?.expected else { return nil }
        return RelativeDifficulty(expected: p)
    }
    var isLast: Bool { index >= questions.count - 1 }
    var isOffline: Bool { usedOfflinePack }

    func start() async {
        stage = .loading
        do {
            let pack = try await service.playPack(mode: config.mode, domain: config.domain, subdomains: config.subdomains,
                                                  count: config.count, ranked: config.ranked, level: config.level)
            begin(pack)
            if config.mode == .quick { Task { await prefetchOfflinePack() } }
        } catch BackendError.offline {
            if config.mode != .errors, let pack: PlayPack = cache.load("offline-pack") {
                cache.remove("offline-pack")
                usedOfflinePack = true
                begin(pack)
            } else {
                stage = .failed("Pas de connexion. Réessaie dans un instant.")
            }
        } catch {
            stage = .failed((error as? LocalizedError)?.errorDescription ?? "Impossible de préparer la partie.")
        }
    }

    private func begin(_ pack: PlayPack) {
        sessionId = pack.sessionId
        questions = pack.questions.filter { $0.reveal != nil }
        guard !questions.isEmpty else {
            stage = .empty(config.mode == .errors ? "Aucune erreur à revoir. Tout est à jour."
                                                  : "Plus de questions disponibles ici pour l'instant. Reviens bientôt.")
            return
        }
        index = 0
        results = []
        attempts = []
        points = 0
        lastPoints = 0
        phase = .answering
        stage = .intro
    }

    /// L'intro est passée : la première question s'affiche.
    func play() {
        guard stage == .intro else { return }
        stage = .playing
    }

    /// Série de bonnes réponses en cours.
    var streak: Int {
        var n = 0
        for correct in results.reversed() { if correct { n += 1 } else { break } }
        return n
    }

    /// Série d'erreurs en cours.
    private var wrongStreak: Int {
        var n = 0
        for correct in results.reversed() { if !correct { n += 1 } else { break } }
        return n
    }

    private var bestStreak: Int {
        var best = 0, run = 0
        for correct in results { run = correct ? run + 1 : 0; best = max(best, run) }
        return best
    }

    /// Un pack de secours pour jouer sans réseau (métro, avion). Les questions du Daily n'y figurent jamais.
    private func prefetchOfflinePack() async {
        guard cache.load("offline-pack", as: PlayPack.self) == nil,
              let pack = try? await service.playPack(mode: .quick, domain: nil, count: 10) else { return }
        cache.save(pack, key: "offline-pack")
    }

    func questionDisplayed() {
        stopwatch.start()
        if let timer = config.timer, phase.isAnswering { deadline = Date().addingTimeInterval(TimeInterval(timer)) }
    }

    /// Temps écoulé : la question compte comme ratée.
    func timeUp() {
        guard phase.isAnswering, let question = current, let reveal = question.reveal else { return }
        stopwatch.pause()
        deadline = nil
        attempts.append(PlayAttempt(questionId: question.id, given: nil, responseMs: stopwatch.elapsedMilliseconds))
        results.append(false)
        lastPoints = 0
        Haptics.error()
        phase = .revealed(given: nil, isCorrect: false, reveal: reveal)
    }
    func pause() { stopwatch.pause() }
    func resume() { if stage == .playing && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) {
        guard phase.isAnswering, let question = current, let reveal = question.reveal else { return }
        stopwatch.pause()
        deadline = nil
        let correct = AnswerEvaluator.isCorrect(given, for: question) ?? false
        attempts.append(PlayAttempt(questionId: question.id, given: given, responseMs: stopwatch.elapsedMilliseconds))
        results.append(correct)
        lastPoints = GamePoints.points(correct: correct, expected: question.expected, responseMs: stopwatch.elapsedMilliseconds)
        points += lastPoints
        correct ? Haptics.success() : Haptics.error()
        phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
    }

    /// Badge immédiat en mode Erreurs : une bonne réponse corrige l'erreur.
    var badge: String? {
        guard case .revealed(_, true, _) = phase else { return nil }
        if config.mode == .errors { return "Erreur corrigée ✓" }
        let gained = lastPoints > 0 ? "+\(lastPoints) pts" : nil
        if streak >= 3 { return [gained, "🔥 \(streak) d'affilée"].compactMap { $0 }.joined(separator: " · ") }
        return gained
    }

    func next() async {
        if isLast {
            await finish()
        } else {
            adaptNextQuestion()
            index += 1
            phase = .answering
            removedOptions = []
            helpText = nil
            helpError = nil
            stopwatch.reset()
        }
    }

    /// Ordre adaptatif (hors mode Erreurs) : après une série de 3, la question restante la plus dure passe devant ;
    /// après 2 erreurs de suite, la plus accessible. Seules les questions pas encore jouées sont réordonnées.
    private func adaptNextQuestion() {
        guard config.mode != .errors, index + 1 < questions.count else { return }
        let remaining = Array(questions[(index + 1)...])
        let pick = AdaptiveOrder.nextIndex(remaining: remaining, correctStreak: streak, wrongStreak: wrongStreak)
        guard pick > 0 else { return }
        questions.swapAt(index + 1, index + 1 + pick)
    }

    /// Terminer plus tôt : ce qui a été joué compte.
    func finish() async {
        guard let sessionId else { return }
        let correct = results.filter { $0 }.count
        var summary = PlaySummary(correct: correct, total: results.count, xp: nil, seeds: nil,
                                  corrected: 0, achievements: [], synced: false)
        summary.ranked = config.countsForElo
        summary.bestStreak = bestStreak
        summary.missed = zip(questions, results).filter { !$0.1 }.map { $0.0 }
        summary.points = points
        for question in questions.prefix(results.count) { summary.answeredByDomain[question.domainId, default: 0] += 1 }
        guard !attempts.isEmpty else {
            stage = .summary(summary)
            return
        }
        stage = .loading
        do {
            let result = try await service.playSubmit(session: sessionId, attempts: attempts)
            summary.xp = result.xp
            summary.seeds = result.seeds
            summary.corrected = result.corrected.count
            summary.achievements = result.achievements
            summary.synced = true
            if let serverPoints = result.points { summary.points = serverPoints }
            summary.ratings = config.countsForElo ? (result.ratings ?? []) : []
            seedsBalance = result.balance
        } catch {
            await queue.enqueue(session: sessionId, attempts: attempts)
        }
        stage = .summary(summary)
    }

    // MARK: Aides (graines)

    func availableHelps(for question: Question) -> [HelpKind] {
        guard !usedOfflinePack, phase.isAnswering else { return [] }
        var kinds: [HelpKind] = []
        if (question.type == .mcq || question.type == .mapPick), (question.payload.options?.count ?? 0) > 2, removedOptions.isEmpty {
            kinds.append(.fiftyFifty)
        }
        if question.hasHint == true, helpText == nil { kinds.append(.hint) }
        if question.hasContext == true, helpText == nil { kinds.append(.context) }
        return kinds
    }

    func useHelp(_ kind: HelpKind) async {
        guard let sessionId, let question = current else { return }
        helpError = nil
        do {
            let content = try await service.spendHelp(session: sessionId, question: question.id, kind: kind)
            seedsBalance = content.balance
            Haptics.soft()
            switch kind {
            case .fiftyFifty: removedOptions = Set(content.remove ?? [])
            case .hint: helpText = content.hint
            case .context: helpText = content.context
            }
        } catch {
            helpError = (error as? LocalizedError)?.errorDescription
        }
    }
}
