import Foundation
import SwiftUI
import CultFiveCore

/// Déroulé d'un 5 du jour. Le serveur fait foi : question servie sans réponse, verdict renvoyé après validation,
/// temps officiel calculé côté serveur. Le client mesure son propre temps (affichage → validation) comme indication.
@MainActor
@Observable
final class DailySessionModel {
    enum Stage: Equatable {
        case loading
        case question
        case finished(DailyResult)
        case failed(String)
    }

    private(set) var stage: Stage = .loading
    private(set) var question: Question?
    private(set) var phase: AnswerPhase = .answering
    private(set) var results: [Bool] = []
    private(set) var position = 1
    private(set) var isRetrying = false
    private(set) var lastVerdict: DailyVerdict?
    /// « Question suivante » touchée : la question s'efface aussitôt, la suivante arrive du serveur.
    /// Le chrono officiel ne démarre qu'à l'envoi par le serveur (pas de préchargement : aucune lecture en avance possible).
    private(set) var advancing = false

    private let service: GameService
    private var runId: UUID?
    private var stopwatch = Stopwatch()
    private var pendingGiven: GivenAnswer?
    private var pendingMs: Int?

    init(service: GameService) {
        self.service = service
    }

    func start() async {
        stage = .loading
        do {
            let start = try await service.dailyStart()
            runId = start.runId
            if let next = start.nextPosition {
                // Reprise : les réponses déjà données viennent du statut.
                let status = try? await service.dailyStatus()
                results = status?.answers ?? []
                await load(position: next)
            } else {
                await showResult()
            }
        } catch {
            stage = .failed(message(for: error))
        }
    }

    private func load(position: Int) async {
        guard let runId else { return }
        self.position = position
        do {
            let response = try await service.dailyQuestion(run: runId, position: position)
            if response.expired {
                await showResult()
                return
            }
            question = response.question
            phase = .answering
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed(message(for: error))
        }
    }

    /// Appelé quand la question est entièrement affichée : l'horloge du joueur démarre.
    func questionDisplayed() {
        stopwatch.start()
    }

    func pause() { stopwatch.pause() }
    func resume() { if stage == .question && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) {
        guard phase.isAnswering, let runId else { return }
        stopwatch.pause()
        let ms = stopwatch.elapsedMilliseconds
        pendingGiven = given
        pendingMs = ms
        phase = .submitting(given)
        Task { await send(runId: runId, given: given, ms: ms) }
    }

    /// Réessai après une coupure réseau : la même réponse, le même temps. Idempotent côté serveur.
    func retry() {
        guard let runId, let given = pendingGiven else { return }
        isRetrying = false
        Task { await send(runId: runId, given: given, ms: pendingMs) }
    }

    private func send(runId: UUID, given: GivenAnswer, ms: Int?) async {
        do {
            let verdict = try await service.dailyAnswer(run: runId, position: position, given: given, clientMs: ms)
            if verdict.expired == true {
                await showResult()
                return
            }
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            lastVerdict = verdict
            Feedback.answer(correct)
            if results.count < position { results.append(correct) }
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pendingGiven = nil
        } catch {
            isRetrying = true
        }
    }

    func next() async {
        guard !advancing else { return }
        Haptics.selection()
        if lastVerdict?.finished == true || position >= 5 {
            await showResult()
        } else {
            advancing = true
            defer { advancing = false }
            await load(position: position + 1)
        }
    }

    private func showResult() async {
        stage = .loading
        do {
            let result = try await service.dailyResult(date: nil)
            results = result.answers.map(\.isCorrect)
            stage = .finished(result)
        } catch {
            stage = .failed(message(for: error))
        }
    }

    private func message(for error: Error) -> String {
        if let backend = error as? BackendError {
            if backend.code == "daily_closed" { return "Le 5 du jour est terminé pour aujourd'hui." }
            return backend.errorDescription ?? "Une erreur est survenue."
        }
        return "Une erreur est survenue."
    }
}
