import Foundation
import SwiftUI
import CultFiveCore

struct PlayConfig: Identifiable, Hashable {
    let id = UUID()
    var mode: PlayMode
    var domain: String? = nil
    var subdomain: String? = nil
    var count: Int = 10

    var title: String {
        switch mode {
        case .quick: return "Partie rapide"
        case .training: return "Entraînement"
        case .surprise: return "Mix surprise"
        case .errors: return "Mes erreurs"
        case .challenge: return "Défi"
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
        var domainMoves: [String: (Double, Double)] = [:]

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
    var isLast: Bool { index >= questions.count - 1 }
    var isOffline: Bool { usedOfflinePack }

    func start() async {
        stage = .loading
        do {
            let pack = try await service.playPack(mode: config.mode, domain: config.domain, subdomain: config.subdomain, count: config.count)
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
        phase = .answering
        stage = .playing
    }

    /// Un pack de secours pour jouer sans réseau (métro, avion). Les questions du Daily n'y figurent jamais.
    private func prefetchOfflinePack() async {
        guard cache.load("offline-pack", as: PlayPack.self) == nil,
              let pack = try? await service.playPack(mode: .quick, domain: nil, subdomain: nil, count: 10) else { return }
        cache.save(pack, key: "offline-pack")
    }

    func questionDisplayed() { stopwatch.start() }
    func pause() { stopwatch.pause() }
    func resume() { if stage == .playing && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) {
        guard phase.isAnswering, let question = current, let reveal = question.reveal else { return }
        stopwatch.pause()
        let correct = AnswerEvaluator.isCorrect(given, for: question) ?? false
        attempts.append(PlayAttempt(questionId: question.id, given: given, responseMs: stopwatch.elapsedMilliseconds))
        results.append(correct)
        correct ? Haptics.success() : Haptics.error()
        phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
    }

    /// Badge immédiat en mode Erreurs : une bonne réponse corrige l'erreur.
    var badge: String? {
        guard config.mode == .errors, case .revealed(_, true, _) = phase else { return nil }
        return "Erreur corrigée ✓"
    }

    func next() async {
        if isLast {
            await finish()
        } else {
            index += 1
            phase = .answering
            removedOptions = []
            helpText = nil
            helpError = nil
            stopwatch.reset()
        }
    }

    /// Terminer plus tôt : ce qui a été joué compte.
    func finish() async {
        guard let sessionId else { return }
        let correct = results.filter { $0 }.count
        var summary = PlaySummary(correct: correct, total: results.count, xp: nil, seeds: nil,
                                  corrected: 0, achievements: [], synced: false)
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
            for item in result.results {
                guard let domain = questions.first(where: { $0.id == item.questionId })?.domainId,
                      let before = item.domainBefore, let after = item.domainAfter else { continue }
                let first = summary.domainMoves[domain]?.0 ?? before
                summary.domainMoves[domain] = (first, after)
            }
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
