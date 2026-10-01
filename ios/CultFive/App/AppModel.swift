import Foundation
import SwiftUI
import UIKit
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
        /// Version trop ancienne (réglée depuis l'admin) : mise à jour demandée.
        case updateRequired
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
    /// Notification ouverte : duel ou ligue à afficher dans l'onglet Amis.
    var pendingDuelId: UUID?
    var pendingLeagueId: UUID?

    let service: GameService
    let api: SupabaseAPI?
    let queue: OfflineAttemptQueue
    let cache = DiskCache()
    /// Pubs AdMob (désactivées en démo et sans serveur).
    let ads: AdsController
    /// Récompenses de pub restantes aujourd'hui, série à sauver, pub entre les parties autorisée.
    var adStatus: AdStatus?

    init(service: GameService, api: SupabaseAPI?, queue: OfflineAttemptQueue) {
        self.service = service
        self.api = api
        self.queue = queue
        self.ads = AdsController(enabled: api != nil)
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
            if let settings = try? await service.appSettings(), Bundle.main.buildNumber < settings.minBuild {
                phase = .updateRequired
                return
            }
            await startReliability(api: api)
            await loadReference()
            // Fuseau et appareil : en arrière-plan, sans retarder l'accueil ; le fuseau seulement s'il a changé.
            let service = self.service
            let timezone = TimeZone.current.identifier
            let sendTimezone = profile?.timezone != timezone
            let device = DeviceIdentity.hash
            Task.detached {
                if sendTimezone { try? await service.setTimezone(timezone) }
                try? await service.registerDevice(hash: device)
            }
            track("app_open", ["os": UIDevice.current.systemVersion])
            phase = (profile?.onboarded ?? false) ? .main : .onboarding
            if phase == .main {
                await refreshDaily()
                await syncPending()
                await NotificationScheduler.registerPushIfAuthorized()
                if let token = AppDelegate.pendingToken {
                    AppDelegate.pendingToken = nil
                    registerPush(token: token)
                }
                await startAds()
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

    /// Profil et progression en parallèle.
    func refreshProfile() async {
        let service = self.service
        async let fresh = try? service.profile()
        async let progress = try? service.progression()
        if let fresh = await fresh { profile = fresh }
        if let progress = await progress { progression = progress }
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

    /// Journal d'usage, envoyé en arrière-plan sans jamais bloquer ni afficher d'erreur.
    func track(_ name: String, _ props: [String: String] = [:]) {
        let event = AppEvent(name: name, props: props, appVersion: Bundle.main.appVersion)
        let service = self.service
        Task.detached { try? await service.trackEvents([event]) }
    }

    func finishOnboarding() async {
        await refreshProfile()
        phase = .main
        // Arrivé par un lien de ligue ou de duel : on l'emmène directement dans Amis.
        tab = pendingLeagueCode != nil || pendingDuelCode != nil ? .friends : .daily
        await refreshDaily()
        await claimPendingInviteIfPossible()
        await startAds()
    }

    // MARK: Pubs

    /// Consentement (RGPD puis suivi Apple) et démarrage des pubs, après l'onboarding seulement.
    func startAds() async {
        await refreshAdStatus()
        ads.adultAudience = isAdult
        await ads.start()
    }

    /// Majeur d'après la tranche d'âge indiquée (facultative) : sans réponse, on reste prudent.
    private var isAdult: Bool {
        guard let range = profile?.ageRange else { return false }
        return range != "13-17"
    }

    func refreshAdStatus() async {
        if let status = try? await service.adStatus() { adStatus = status }
    }

    /// Pubs de test de Google : Google ne prévient pas notre serveur, qui accepte alors la récompense pour un admin.
    private var adTestClaims: Bool { ads.testAds && (adStatus?.admin ?? false) }

    /// Pub récompensée : vérifie que la récompense est possible, montre la pub, puis demande la récompense au serveur
    /// (qui attend la confirmation de Google). `nil` si la pub a été fermée avant la fin.
    func watchAd(_ kind: AdKind, ref: String? = nil) async throws -> AdReward? {
        try await service.adCan(kind, ref: ref)
        guard let user = profile?.id else { throw BackendError.notAuthenticated }
        track("ad_offer", ["kind": kind.rawValue])
        ads.adultAudience = isAdult
        guard try await ads.showRewarded(kind, userId: user, ref: ref) else { return nil }
        track("ad_view", ["kind": kind.rawValue])
        let service = self.service
        let test = adTestClaims
        let reward = try await claimAd { try await service.adClaim(kind, ref: ref, test: test) }
        track("ad_reward", ["kind": kind.rawValue])
        await refreshAdStatus()
        await refreshProfile()
        return reward
    }

    /// « Corrige tes erreurs » débloquée par une pub : renvoie les questions à rejouer.
    func watchCorrectionAd(session: UUID) async throws -> CorrectionStart? {
        let ref = session.uuidString.lowercased()
        try await service.adCan(.correction, ref: ref)
        guard let user = profile?.id else { throw BackendError.notAuthenticated }
        track("ad_offer", ["kind": AdKind.correction.rawValue])
        ads.adultAudience = isAdult
        guard try await ads.showRewarded(.correction, userId: user, ref: ref) else { return nil }
        track("ad_view", ["kind": AdKind.correction.rawValue])
        let service = self.service
        let test = adTestClaims
        let start = try await claimAd { try await service.correctionStart(session: session, test: test) }
        track("ad_reward", ["kind": AdKind.correction.rawValue])
        return start
    }

    /// Google confirme la vue en quelques secondes : on réessaie tant que le serveur répond « en attente ».
    private func claimAd<T>(_ claim: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await claim()
            } catch let error as BackendError where error.code == "ad_pending" && attempt < 12 {
                attempt += 1
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    /// Entre deux parties Jouer (après le bilan) : pub plein écran si elle est due.
    func interstitialBetweenGames() async {
        ads.adultAudience = isAdult
        if await ads.showInterstitialIfDue(allowed: adStatus?.interstitial ?? false) {
            track("interstitial")
        }
    }

    func signOut() async {
        if let token = UserDefaults.standard.string(forKey: Self.pushTokenKey) {
            try? await service.pushUnregister(token: token)
            UserDefaults.standard.removeObject(forKey: Self.pushTokenKey)
        }
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

    // MARK: Fiabilité

    private var diagnostics: DiagnosticsReporter?
    /// Erreurs déjà signalées (une fois par fonction et par type d'erreur et par lancement).
    private var reportedErrors: Set<String> = []

    /// Plantages (MetricKit) et échecs techniques des appels au serveur, envoyés à l'onglet Santé de l'admin.
    private func startReliability(api: SupabaseAPI) async {
        if diagnostics == nil { diagnostics = DiagnosticsReporter(service: service) }
        await api.setErrorHandler { [weak self] function, code in
            Task { @MainActor in self?.reportError(function: function, code: code) }
        }
    }

    private func reportError(function: String, code: String) {
        let key = "\(function):\(code)"
        guard reportedErrors.count < 50, reportedErrors.insert(key).inserted else { return }
        track("client_error", ["function": function, "code": code])
    }

    // MARK: Notifications push

    private static let pushTokenKey = "pushToken"

    /// Jeton de l'iPhone pour les notifications push, envoyé au serveur (production en TestFlight / App Store).
    func registerPush(token data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: Self.pushTokenKey)
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let service = self.service
        Task.detached { try? await service.pushRegister(token: token, environment: environment) }
    }

    /// Notification touchée : on ouvre l'onglet Amis sur le duel ou la ligue concernés.
    func openNotification(_ info: [AnyHashable: Any]) {
        guard phase == .main else { return }
        let id = (info["id"] as? String).flatMap(UUID.init(uuidString:))
        switch info["type"] as? String {
        case "duel":
            tab = .friends
            pendingDuelId = id
        case "league":
            tab = .friends
            pendingLeagueId = id
        case "friends", "friend":
            tab = .friends
        default:
            break
        }
    }

    /// Proposée après un geste social (duel lancé, ligue rejointe) : être prévenu quand l'autre joue.
    func askNotificationsAfterSocial() {
        Task { _ = await NotificationScheduler.requestAuthorization() }
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

extension Bundle {
    /// Numéro de build (CFBundleVersion), comparé à la version minimale réglée dans l'admin.
    var buildNumber: Int {
        Int(infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    /// « 1.4 (37) » : version et numéro de build.
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
