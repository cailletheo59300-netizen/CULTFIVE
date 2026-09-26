import Foundation

/// Mesure le temps de réponse : de l'affichage complet de la question à la validation.
/// Horloge monotone (insensible aux changements d'heure système). Le temps de lecture des explications n'est jamais compté.
public struct Stopwatch: Sendable {
    private var startedAt: ContinuousClock.Instant?
    private var accumulated: Duration = .zero

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public mutating func start() {
        guard startedAt == nil else { return }
        startedAt = ContinuousClock.now
    }

    /// Pause (app en arrière-plan) : le serveur garde sa propre horloge pour le Daily.
    public mutating func pause() {
        guard let startedAt else { return }
        accumulated += ContinuousClock.now - startedAt
        self.startedAt = nil
    }

    public mutating func reset() {
        startedAt = nil
        accumulated = .zero
    }

    public var elapsedMilliseconds: Int {
        var total = accumulated
        if let startedAt { total += ContinuousClock.now - startedAt }
        let (seconds, attoseconds) = total.components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
