import Foundation

/// File persistante des tentatives du mode Jouer non encore synchronisées (hors-ligne, crash, fermeture).
/// Idempotente côté serveur (client_attempt_id) : on peut renvoyer sans risque de double comptage.
/// Le Daily n'y passe jamais : il est validé question par question, en ligne.
public actor OfflineAttemptQueue {
    public struct Batch: Codable, Hashable, Sendable {
        public let sessionId: UUID
        public var attempts: [PlayAttempt]
    }

    private let fileURL: URL?
    private var batches: [Batch]

    /// `fileURL` nil : file en mémoire (tests, prévisualisations).
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Batch].self, from: data) {
            batches = saved
        } else {
            batches = []
        }
    }

    public var pendingCount: Int { batches.reduce(0) { $0 + $1.attempts.count } }

    public func enqueue(session: UUID, attempts: [PlayAttempt]) {
        guard !attempts.isEmpty else { return }
        if let index = batches.firstIndex(where: { $0.sessionId == session }) {
            let known = Set(batches[index].attempts.map(\.clientAttemptId))
            batches[index].attempts.append(contentsOf: attempts.filter { !known.contains($0.clientAttemptId) })
        } else {
            batches.append(Batch(sessionId: session, attempts: attempts))
        }
        persist()
    }

    /// Envoie chaque lot ; ceux qui échouent restent en file. Renvoie le nombre de lots envoyés.
    @discardableResult
    public func drain(using send: @Sendable (UUID, [PlayAttempt]) async throws -> Void) async -> Int {
        var sent = 0
        for batch in batches {
            do {
                try await send(batch.sessionId, batch.attempts)
                batches.removeAll { $0.sessionId == batch.sessionId }
                sent += 1
                persist()
            } catch {
                continue
            }
        }
        return sent
    }

    public func remove(session: UUID) {
        batches.removeAll { $0.sessionId == session }
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        if let data = try? JSONEncoder().encode(batches) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
