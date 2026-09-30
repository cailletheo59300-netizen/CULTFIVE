import Foundation
import SwiftUI
import CultFiveCore

/// État global de l'app : session, profil, statut du Daily, référentiel. Source unique pour les onglets.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case onboarding
        case main
        case unavailable(String)
    }

    enum Tab: Hashable { case play, daily, friends, profile }

    var phase: Phase = .launching
    var tab: Tab = .daily
    var profile: Profile?
    var daily: DailyStatus?
    /// Coffres à ouvrir, arbre de Léon, tickets, tenue. Mis à jour après chaque partie et chaque ouverture.
    var progression: ProgressionOverview?
    /// Coffres présentés en plein écran (ouverture à la chaîne).
    var chestQueue: [ChestRef]?
    var domains: [DomainInfo] = []
    var subdomains: [SubdomainInfo] = []
    var toast: String?
    /// Code d'invitation reçu par lien, réclamé dès que le compte n'est plus anonyme.
    var pendingInvite: String?
    var pendingLeagueCode: String?
    /// Défi reçu par lien (…/d/CODE), rejoint depuis l'onglet Amis.
    var pendingDuelCode: String?

    let service: GameService
    let api: SupabaseAPI?
    let queue: OfflineAttemptQueue
    let cache = DiskCache()

    init(service: GameService, api: SupabaseAPI?, queue: OfflineAttemptQueue) {
        self.service = service
        self.api = api
        self.queue = queue
        self.domains = cache.load("domains") ?? []
        self.subdomains = cache.load("subdomains") ?? []
        self.pendingInvite = UserDefaults.standard.string(forKey: "pendingInvite")
    }

    static func live() -> AppModel {
        #if DEBUG
        if let screen = Demo.screen {
            return AppModel(service: DemoGameService(screen: screen), api: nil, queue: OfflineAttemptQueue(fileURL: nil))
        }
        #endif
        let queue = OfflineAttemptQueue(fileURL: DiskCache.queueURL)
        guard let config = AppConfig.backend else {
            let model = AppModel(service: UnavailableService(), api: nil, queue: queue)
            model.phase = .unavailable("Configuration serveur manquante. Renseigne ios/Config/Secrets.xcconfig (voir README).")
            return model
        }
        let api = SupabaseAPI(config: config, store: KeychainSessionStore())
        return AppModel(service: LiveGameService(api: api), api: api, queue: queue)
    }

    // MARK: Démarrage

    private var bootstrapAttempts = 0

    func bootstrap() async {
        #if DEBUG
        if let screen = Demo.screen {
            await bootstrapDemo(screen)
            return
        }
        #endif
        guard let api else { return }
        bootstrapAttempts += 1
        do {
            if await api.session == nil {
                try await api.signInAnonymously()
            }
            try await loadProfile()
            await loadReference()
            try? await service.setTimezone(TimeZone.current.identifier)
            try? await service.registerDevice(hash: DeviceIdentity.hash)
            phase = (profile?.onboarded ?? false) ? .main : .onboarding
            if phase == .main {
                await refreshDaily()
                await syncPending()
            }
        } catch BackendError.notAuthenticated where bootstrapAttempts < 3 {
            // Session révoquée (compte supprimé ailleurs…) : on repart d'un compte neuf.
            await api.clearLocalSession()
            phase = .launching
            await bootstrap()
        } catch {
            if profile != nil {
                phase = profile?.onboarded == true ? .main : .onboarding
            } else {
                phase = .unavailable((error as? LocalizedError)?.errorDescription ?? "Connexion impossible.")
            }
        }
    }

    #if DEBUG
    /// Mode démo : données enregistrées, aucun réseau. Ouvre directement l'écran demandé.
    private func bootstrapDemo(_ screen: Demo.Screen) async {
        profile = try? await service.profile()
        domains = (try? await service.domains()) ?? []
        subdomains = (try? await service.subdomains()) ?? []
        daily = try? await service.dailyStatus()
        switch screen {
        case .onboarding, .onboardingQuestion: phase = .onboarding
        case .play, .domain: phase = .main; tab = .play
        case .friends, .league: phase = .main; tab = .friends
        case .profile: phase = .main; tab = .profile
        default: phase = .main; tab = .daily
        }
    }
    #endif

    func retryLaunch() async {
        phase = .launching
        bootstrapAttempts = 0
        await bootstrap()
    }

    // MARK: Données

    func loadProfile() async throws {
        profile = try await service.profile()
    }

    func refreshProfile() async {
        if let fresh = try? await service.profile() { profile = fresh }
        await refreshProgression()
    }

    func refreshProgression() async {
        if let fresh = try? await service.progression() { progression = fresh }
    }

    /// Ouvre la séance d'ouverture des coffres (tous ceux en attente, ou ceux donnés).
    func openChests(_ chests: [ChestRef]? = nil) {
        let list = chests ?? progression?.chests ?? []
        guard !list.isEmpty else { return }
        chestQueue = list
    }

    /// Tenue de Léon (emplacement → objet), portée partout où il apparaît.
    var outfit: LeonOutfit {
        var outfit = LeonOutfit(progression?.outfit ?? [:])
        if outfit.form == nil { outfit.form = progression?.bestForm }
        return outfit
    }

    func refreshDaily() async {
        guard let status = try? await service.dailyStatus() else { return }
        daily = status
        if let profile {
            await NotificationScheduler.refresh(profile: profile, dailyDone: status.state == .done)
        }
    }

    func loadReference() async {
        if let fresh = try? await service.domains(), !fresh.isEmpty {
            domains = fresh
            cache.save(fresh, key: "domains")
        }
        if let fresh = try? await service.subdomains(), !fresh.isEmpty {
            subdomains = fresh
            cache.save(fresh, key: "subdomains")
        }
    }

    func domainName(_ id: String) -> String {
        domains.first { $0.id == id }?.name ?? DomainPalette.fallbackName(id)
    }

    func subdomains(of domain: String) -> [SubdomainInfo] {
        subdomains.filter { $0.domainId == domain }.sorted { $0.sort < $1.sort }
    }

    /// Renvoie les tentatives de jeu restées en file (hors-ligne, crash).
    func syncPending() async {
        let service = self.service
        let sent = await queue.drain { session, attempts in
            _ = try await service.playSubmit(session: session, attempts: attempts)
        }
        if sent > 0 { await refreshProfile() }
    }

    func show(_ message: String) {
        withAnimation(Motion.standard) { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(Motion.standard) { if toast == message { toast = nil } }
        }
    }

    // MARK: Compte

    var isAnonymous: Bool { profile?.isAnonymous ?? true }

    func finishOnboarding() async {
        await refreshProfile()
        phase = .main
        tab = .daily
        await refreshDaily()
        await claimPendingInviteIfPossible()
    }

    func signOut() async {
        await api?.signOut()
        NotificationScheduler.cancelAll()
        profile = nil
        daily = nil
        phase = .launching
        await bootstrap()
    }

    func deleteAccount() async throws {
        try await service.deleteAccount()
        await api?.clearLocalSession()
        NotificationScheduler.cancelAll()
        profile = nil
        daily = nil
        phase = .launching
        await bootstrap()
    }

    // MARK: Liens

    /// brainlix://i/CODE, https://brainlix.site/i/CODE (invitation) ; …/l/CODE (ligue) ; …/d/CODE (duel).
    func handle(url: URL) {
        let parts = (url.host.map { [$0] } ?? []) + url.pathComponents.filter { $0 != "/" }
        let meaningful = parts.filter { $0 != "brainlix.site" && $0 != "www.brainlix.site" }
        guard meaningful.count >= 2 else { return }
        let code = meaningful[1].uppercased()
        switch meaningful[0] {
        case "i":
            pendingInvite = code
            UserDefaults.standard.set(code, forKey: "pendingInvite")
            Task { await claimPendingInviteIfPossible() }
        case "l":
            pendingLeagueCode = code
            tab = .friends
        case "d":
            pendingDuelCode = code
            tab = .friends
        default:
            break
        }
    }

    func claimPendingInviteIfPossible() async {
        guard let code = pendingInvite, let profile, !profile.isAnonymous else { return }
        do {
            let result = try await service.claimReferral(code: code, deviceHash: DeviceIdentity.hash)
            if result.status == "claimed" {
                show("\(result.inviter ?? "Ton ami") t'a invité · +\(result.seeds ?? 0) \(Brand.currencyPlural)")
                await refreshProfile()
            }
            clearInvite()
        } catch let error as BackendError where error.code == "referral_already_claimed" || error.code == "referral_code_invalid" {
            clearInvite()
        } catch {
            // Réessai au prochain lancement.
        }
    }

    private func clearInvite() {
        pendingInvite = nil
        UserDefaults.standard.removeObject(forKey: "pendingInvite")
    }
}

/// Service utilisé quand la configuration manque : toutes les requêtes échouent proprement.
struct UnavailableService: GameService {
    private func fail<T>() throws -> T { throw BackendError.offline }
    func dailyStatus() async throws -> DailyStatus { try fail() }
    func dailyStart() async throws -> DailyStart { try fail() }
    func dailyQuestion(run: UUID, position: Int) async throws -> DailyQuestionResponse { try fail() }
    func dailyAnswer(run: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict { try fail() }
    func dailyResult(date: String?) async throws -> DailyResult { try fail() }
    func dailyReview(date: String?) async throws -> [ReviewItem] { try fail() }
    func dailyHistory(days: Int) async throws -> [DailyHistoryEntry] { try fail() }
    func quests() async throws -> QuestsOverview { try fail() }
    func weeklyRecap(weeks: Int) async throws -> [WeekRecap] { try fail() }
    func onboardingPack() async throws -> PlayPack { try fail() }
    func playPack(mode: PlayMode, domain: String?, subdomains: [String], count: Int, ranked: Bool,
                  level: PlayLevel) async throws -> PlayPack { try fail() }
    func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult { try fail() }
    func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent { try fail() }
    func reportQuestion(_ question: UUID, reason: String, note: String?) async throws { try fail() as Void }
    func duels() async throws -> [Duel] { try fail() }
    func duelCreate(friend: UUID?) async throws -> Duel { try fail() }
    func duelJoin(code: String) async throws -> Duel { try fail() }
    func duelDecline(_ duel: UUID) async throws { try fail() as Void }
    func duelQuestion(duel: UUID, position: Int) async throws -> DailyQuestionResponse { try fail() }
    func duelAnswer(duel: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict { try fail() }
    func duelResult(_ duel: UUID) async throws -> Duel { try fail() }
    func profile() async throws -> Profile { try fail() }
    func handleAvailable(_ handle: String) async throws -> HandleAvailability { try fail() }
    func setHandle(_ handle: String) async throws -> Profile { try fail() }
    func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile { try fail() }
    func completeOnboarding(level: String, interests: [String]) async throws -> Profile { try fail() }
    func setTimezone(_ identifier: String) async throws { try fail() as Void }
    func registerDevice(hash: String) async throws { try fail() as Void }
    func skills() async throws -> [SkillSummary] { try fail() }
    func domainStats(_ domain: String) async throws -> DomainStats { try fail() }
    func errors() async throws -> ErrorsOverview { try fail() }
    func achievements() async throws -> [AchievementRef] { try fail() }
    func deleteAccount() async throws { try fail() as Void }
    func progression() async throws -> ProgressionOverview { try fail() }
    func openChest(_ chest: UUID) async throws -> ChestContents { try fail() }
    func feedTree(amount: Int, clientId: UUID) async throws -> TreeFeedResult { try fail() }
    func equip(slot: String, item: String?) async throws -> [String: String] { try fail() }
    func trophies() async throws -> TrophiesOverview { try fail() }
    func shop() async throws -> ShopOverview { try fail() }
    func buy(_ item: String) async throws -> ShopPurchase { try fail() }
    func friends() async throws -> FriendsOverview { try fail() }
    func searchHandles(_ query: String) async throws -> [HandleSearchResult] { try fail() }
    func requestFriend(handle: String) async throws -> FriendRequestResult { try fail() }
    func respondFriend(friendship: UUID, accept: Bool) async throws { try fail() as Void }
    func removeFriend(_ user: UUID) async throws { try fail() as Void }
    func blockUser(_ user: UUID) async throws { try fail() as Void }
    func claimReferral(code: String, deviceHash: String) async throws -> ReferralClaimResult { try fail() }
    func referralOverview() async throws -> ReferralOverview { try fail() }
    func leagues() async throws -> [LeagueSummary] { try fail() }
    func createLeague(name: String, period: LeaguePeriod) async throws -> LeagueStandings { try fail() }
    func joinLeague(code: String) async throws -> LeagueStandings { try fail() }
    func leaveLeague(_ id: UUID) async throws { try fail() as Void }
    func leagueStandings(_ id: UUID, offset: Int) async throws -> LeagueStandings { try fail() }
    func domains() async throws -> [DomainInfo] { try fail() }
    func subdomains() async throws -> [SubdomainInfo] { try fail() }
}
