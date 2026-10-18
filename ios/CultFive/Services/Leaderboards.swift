import Foundation
import Observation
import CultFiveCore

/// Classements gardés sur le téléphone (D-080) : le dernier connu s'affiche tout de suite, puis se met à jour.
/// Préchargés avant l'écran (dernière réponse du 5 du jour, onglet Jouer) ; une seule demande à la fois par classement.
@MainActor @Observable
final class Leaderboards {
    static let shared = Leaderboards()

    private(set) var boards: [String: DailyLeaderboard]
    @ObservationIgnored private var inFlight: [String: Task<DailyLeaderboard?, Never>] = [:]
    @ObservationIgnored private var fetchedAt: [String: Date] = [:]
    @ObservationIgnored private let cache = DiskCache()
    private static let cacheKey = "leaderboards"

    private init() {
        boards = cache.load(Self.cacheKey) ?? [:]
    }

    static func daily(_ date: String) -> String { "daily:\(date)" }
    static func domain(_ id: String) -> String { "domain:\(id)" }

    func board(_ key: String) -> DailyLeaderboard? { boards[key] }

    /// Met à jour le classement ; si une demande est déjà en cours, l'attend au lieu d'en relancer une.
    /// `maxAge` : pas de nouvelle demande si le classement a été chargé depuis moins longtemps.
    @discardableResult
    func refresh(_ key: String, maxAge: TimeInterval = 0,
                 fetch: @escaping @Sendable () async throws -> DailyLeaderboard) async -> DailyLeaderboard? {
        if maxAge > 0, let at = fetchedAt[key], Date().timeIntervalSince(at) < maxAge { return boards[key] }
        if let running = inFlight[key] { return await running.value }
        let task = Task { try? await fetch() }
        inFlight[key] = task
        let fresh = await task.value
        inFlight[key] = nil
        if let fresh {
            fetchedAt[key] = Date()
            if boards[key] != fresh { boards[key] = fresh }
            save()
        }
        return fresh ?? boards[key]
    }

    func refreshDaily(_ service: GameService, date: String, maxAge: TimeInterval = 0) async {
        await refresh(Self.daily(date), maxAge: maxAge) { try await service.dailyLeaderboard(date: date) }
    }

    func refreshDomain(_ service: GameService, domain: String, maxAge: TimeInterval = 0) async {
        await refresh(Self.domain(domain), maxAge: maxAge) { try await service.domainLeaderboard(domain: domain) }
    }

    /// Précharge les classements de plusieurs domaines, quelques-uns à la fois.
    func prefetchDomains(_ service: GameService, ids: [String]) async {
        for chunk in stride(from: 0, to: ids.count, by: 4).map({ Array(ids[$0..<min($0 + 4, ids.count)]) }) {
            await withTaskGroup(of: Void.self) { group in
                for id in chunk {
                    group.addTask { await self.refreshDomain(service, domain: id, maxAge: 120) }
                }
            }
        }
    }

    /// Déconnexion : rien ne reste du compte précédent.
    func clear() {
        boards = [:]
        fetchedAt = [:]
        inFlight.values.forEach { $0.cancel() }
        inFlight = [:]
        cache.remove(Self.cacheKey)
    }

    private func save() {
        // Le 5 du jour : seuls les deux derniers jours valent la peine d'être gardés.
        let dailies = boards.keys.filter { $0.hasPrefix("daily:") }.sorted()
        for old in dailies.dropLast(2) { boards[old] = nil }
        cache.save(boards, key: Self.cacheKey)
    }
}
