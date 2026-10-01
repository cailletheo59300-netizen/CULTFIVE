import Foundation

/// Façade typée de toutes les RPC Brainlix. Les écrans ne parlent qu'à ce protocole.
public protocol GameService: Sendable {
    // Daily
    func dailyStatus() async throws -> DailyStatus
    func dailyStart() async throws -> DailyStart
    func dailyQuestion(run: UUID, position: Int) async throws -> DailyQuestionResponse
    func dailyAnswer(run: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict
    func dailyResult(date: String?) async throws -> DailyResult
    func dailyReview(date: String?) async throws -> [ReviewItem]
    func dailyHistory(days: Int) async throws -> [DailyHistoryEntry]

    // Objectifs et récap
    func quests() async throws -> QuestsOverview
    func weeklyRecap(weeks: Int) async throws -> [WeekRecap]

    // Jouer
    func onboardingPack() async throws -> PlayPack
    /// `subdomains` : sous-thèmes choisis (vide = tout le domaine). `ranked = false` : entraînement libre à difficulté `level`.
    func playPack(mode: PlayMode, domain: String?, subdomains: [String], count: Int, ranked: Bool, level: PlayLevel) async throws -> PlayPack
    func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult
    func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent
    /// Signalement d'une question (réponse fausse, ambiguë, faute, plus à jour, autre).
    func reportQuestion(_ question: UUID, reason: String, note: String?) async throws
    /// Journal d'usage (ouverture, onboarding, partage…), stocké dans la base Brainlix uniquement.
    func trackEvents(_ events: [AppEvent]) async throws
    /// « Corrige tes erreurs » : ouvre la correction de la dernière partie, puis envoie les réponses.
    /// Ouverture après une pub vue (`test` : pubs de test, réservé aux admins).
    func correctionStart(session: UUID, test: Bool) async throws -> CorrectionStart
    func correctionSubmit(session: UUID, answers: [(UUID, GivenAnswer?)]) async throws -> CorrectionResult
    /// Pubs récompensées : état du jour, vérification avant la pub, récompense après (vérifiée par le serveur).
    func adStatus() async throws -> AdStatus
    func adCan(_ kind: AdKind, ref: String?) async throws
    func adClaim(_ kind: AdKind, ref: String?, test: Bool) async throws -> AdReward

    // Profil & progression
    func profile() async throws -> Profile
    func handleAvailable(_ handle: String) async throws -> HandleAvailability
    func setHandle(_ handle: String) async throws -> Profile
    func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile
    func completeOnboarding(level: String, interests: [String]) async throws -> Profile
    func setTimezone(_ identifier: String) async throws
    func registerDevice(hash: String) async throws
    func skills() async throws -> [SkillSummary]
    func domainStats(_ domain: String) async throws -> DomainStats
    func errors() async throws -> ErrorsOverview
    func achievements() async throws -> [AchievementRef]
    func deleteAccount() async throws

    // Coffres, arbre de Léon, tenue, trophées
    func progression() async throws -> ProgressionOverview
    func openChest(_ chest: UUID) async throws -> ChestContents
    /// `clientId` rend l'appel idempotent (renvoi réseau).
    func feedTree(amount: Int, clientId: UUID) async throws -> TreeFeedResult
    /// `item` nil : retire l'objet de cet emplacement. Renvoie la tenue complète.
    func equip(slot: String, item: String?) async throws -> [String: String]
    func trophies() async throws -> TrophiesOverview
    func shop() async throws -> ShopOverview
    func buy(_ item: String) async throws -> ShopPurchase

    // Social
    func friends() async throws -> FriendsOverview
    // Duels
    func duels() async throws -> [Duel]
    /// `friend` nil : défi ouvert, à partager par lien.
    func duelCreate(friend: UUID?) async throws -> Duel
    /// Duel réglé (nombre de questions, domaines, difficulté).
    func duelCreate(friend: UUID?, settings: DuelSettings) async throws -> Duel
    /// Revanche : même adversaire, mêmes réglages.
    func duelRematch(_ duel: UUID) async throws -> Duel
    /// Profil d'un ami et face-à-face.
    func friendProfile(_ friend: UUID) async throws -> FriendProfile
    func duelJoin(code: String) async throws -> Duel
    func duelDecline(_ duel: UUID) async throws
    func duelQuestion(duel: UUID, position: Int) async throws -> DailyQuestionResponse
    func duelAnswer(duel: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict
    func duelResult(_ duel: UUID) async throws -> Duel
    func searchHandles(_ query: String) async throws -> [HandleSearchResult]
    func requestFriend(handle: String) async throws -> FriendRequestResult
    func respondFriend(friendship: UUID, accept: Bool) async throws
    func removeFriend(_ user: UUID) async throws
    func blockUser(_ user: UUID) async throws
    func claimReferral(code: String, deviceHash: String) async throws -> ReferralClaimResult
    func referralOverview() async throws -> ReferralOverview
    func leagues() async throws -> [LeagueSummary]
    func createLeague(name: String, period: LeaguePeriod) async throws -> LeagueStandings
    func joinLeague(code: String) async throws -> LeagueStandings
    func leaveLeague(_ id: UUID) async throws
    func leagueStandings(_ id: UUID, offset: Int) async throws -> LeagueStandings
    /// Signaler un joueur ou une ligue (kind : user · league ; reason : name · behavior · cheating · other).
    func reportContent(kind: String, target: UUID, reason: String, note: String?) async throws
    /// Export de mes données personnelles (JSON).
    func dataExport() async throws -> Data
    /// Notifications push : jeton de l'iPhone (hexadécimal) ; environment = production · sandbox.
    func pushRegister(token: String, environment: String) async throws
    func pushUnregister(token: String) async throws
    // Ligues v2 : quiz du jour propre à la ligue, saisons, aperçu avant de rejoindre.
    func createLeague(_ draft: LeagueDraft) async throws -> LeagueStandings
    func leaguePreview(code: String) async throws -> LeaguePreview
    func leagueQuestion(league: UUID, position: Int) async throws -> DailyQuestionResponse
    func leagueAnswer(league: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict
    func leagueDayResult(league: UUID) async throws -> LeagueDayResult
    func leagueNewSeason(league: UUID, startToday: Bool) async throws -> LeagueStandings
    func leagueRegenerateCode(league: UUID) async throws -> String
    func leagueKick(league: UUID, user: UUID) async throws

    // Référentiel
    func domains() async throws -> [DomainInfo]
    func subdomains() async throws -> [SubdomainInfo]
}

public struct LiveGameService: GameService {
    public let api: SupabaseAPI

    public init(api: SupabaseAPI) {
        self.api = api
    }

    private func encode<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func optional(_ value: String?) -> JSONValue {
        value.map(JSONValue.string) ?? .null
    }

    // MARK: Daily

    public func dailyStatus() async throws -> DailyStatus { try await api.rpc("daily_status") }
    public func dailyStart() async throws -> DailyStart { try await api.rpc("daily_start") }

    public func dailyQuestion(run: UUID, position: Int) async throws -> DailyQuestionResponse {
        try await api.rpc("daily_question", ["p_run": .string(run.uuidString), "p_position": .number(Double(position))])
    }

    public func dailyAnswer(run: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict {
        try await api.rpc("daily_answer", [
            "p_run": .string(run.uuidString),
            "p_position": .number(Double(position)),
            "p_given": given?.json ?? .null,
            "p_client_ms": clientMs.map { .number(Double($0)) } ?? .null,
        ])
    }

    public func dailyResult(date: String?) async throws -> DailyResult {
        try await api.rpc("daily_result", ["p_date": optional(date)])
    }

    public func dailyReview(date: String?) async throws -> [ReviewItem] {
        try await api.rpc("daily_review", ["p_date": optional(date)])
    }

    public func dailyHistory(days: Int) async throws -> [DailyHistoryEntry] {
        try await api.rpc("daily_history", ["p_days": .number(Double(days))])
    }

    // MARK: Jouer

    public func onboardingPack() async throws -> PlayPack { try await api.rpc("onboarding_pack") }

    public func playPack(mode: PlayMode, domain: String?, subdomains: [String], count: Int, ranked: Bool,
                         level: PlayLevel) async throws -> PlayPack {
        try await api.rpc("play_pack", ["p_mode": .string(mode.rawValue), "p_domain": optional(domain),
                                        "p_subdomains": subdomains.isEmpty ? .null : .array(subdomains.map(JSONValue.string)),
                                        "p_count": .number(Double(count)), "p_ranked": .bool(ranked),
                                        "p_level": .string(level.rawValue)])
    }

    public func correctionStart(session: UUID, test: Bool) async throws -> CorrectionStart {
        try await api.rpc("play_correction_start", ["p_session": .string(session.uuidString), "p_via": .string("ad"),
                                                     "p_test": .bool(test)])
    }

    public func adStatus() async throws -> AdStatus {
        try await api.rpc("ad_status")
    }

    public func adCan(_ kind: AdKind, ref: String?) async throws {
        try await api.rpcVoid("ad_can", ["p_kind": .string(kind.rawValue), "p_ref": ref.map(JSONValue.string) ?? .null])
    }

    public func adClaim(_ kind: AdKind, ref: String?, test: Bool) async throws -> AdReward {
        try await api.rpc("ad_claim", ["p_kind": .string(kind.rawValue), "p_ref": ref.map(JSONValue.string) ?? .null,
                                       "p_test": .bool(test)])
    }

    public func correctionSubmit(session: UUID, answers: [(UUID, GivenAnswer?)]) async throws -> CorrectionResult {
        let list = answers.map { id, given in
            JSONValue.object(["question_id": .string(id.uuidString), "given": given?.json ?? .null])
        }
        return try await api.rpc("play_correction_submit", ["p_session": .string(session.uuidString), "p_answers": .array(list)])
    }

    public func trackEvents(_ events: [AppEvent]) async throws {
        guard !events.isEmpty else { return }
        try await api.rpcVoid("track_events", ["p_events": .array(events.map(\.json))])
    }

    public func reportQuestion(_ question: UUID, reason: String, note: String?) async throws {
        try await api.rpcVoid("report_question", ["p_question": .string(question.uuidString),
                                                  "p_reason": .string(reason), "p_note": optional(note)])
    }

    public func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult {
        try await api.rpc("play_submit", ["p_session": .string(session.uuidString), "p_attempts": try encode(attempts)])
    }

    public func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent {
        try await api.rpc("play_spend_help", ["p_session": .string(session.uuidString),
                                              "p_question": .string(question.uuidString), "p_kind": .string(kind.rawValue)])
    }

    // MARK: Profil

    public func profile() async throws -> Profile { try await api.rpc("profile_me") }

    public func handleAvailable(_ handle: String) async throws -> HandleAvailability {
        try await api.rpc("handle_available", ["p_handle": .string(handle)])
    }

    public func setHandle(_ handle: String) async throws -> Profile {
        try await api.rpc("set_handle", ["p_handle": .string(handle)])
    }

    public func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile {
        try await api.rpc("profile_update", ["p": .object(fields)])
    }

    public func completeOnboarding(level: String, interests: [String]) async throws -> Profile {
        try await api.rpc("complete_onboarding", ["p_prior_level": .string(level),
                                                  "p_interests": .array(interests.map(JSONValue.string))])
    }

    public func setTimezone(_ identifier: String) async throws {
        try await api.rpcVoid("set_timezone", ["p_tz": .string(identifier)])
    }

    public func registerDevice(hash: String) async throws {
        try await api.rpcVoid("register_device", ["p_device_hash": .string(hash)])
    }

    public func quests() async throws -> QuestsOverview { try await api.rpc("quests_overview") }

    public func weeklyRecap(weeks: Int) async throws -> [WeekRecap] {
        try await api.rpc("weekly_recap", ["p_weeks": .number(Double(weeks))])
    }

    public func skills() async throws -> [SkillSummary] { try await api.rpc("skills_overview") }

    public func domainStats(_ domain: String) async throws -> DomainStats {
        try await api.rpc("domain_stats", ["p_domain": .string(domain)])
    }

    public func errors() async throws -> ErrorsOverview { try await api.rpc("errors_overview") }
    public func achievements() async throws -> [AchievementRef] { try await api.rpc("achievements_mine") }
    public func deleteAccount() async throws { try await api.rpcVoid("delete_account") }

    // MARK: Coffres, arbre, tenue, trophées

    public func progression() async throws -> ProgressionOverview { try await api.rpc("progression_overview") }

    public func openChest(_ chest: UUID) async throws -> ChestContents {
        try await api.rpc("chest_open", ["p_chest": .string(chest.uuidString)])
    }

    public func feedTree(amount: Int, clientId: UUID) async throws -> TreeFeedResult {
        try await api.rpc("tree_feed", ["p_amount": .number(Double(amount)), "p_client_id": .string(clientId.uuidString)])
    }

    public func equip(slot: String, item: String?) async throws -> [String: String] {
        try await api.rpc("leon_equip", ["p_slot": .string(slot), "p_item": optional(item)])
    }

    public func trophies() async throws -> TrophiesOverview { try await api.rpc("trophies_overview") }
    public func shop() async throws -> ShopOverview { try await api.rpc("shop_overview") }
    public func buy(_ item: String) async throws -> ShopPurchase { try await api.rpc("shop_buy", ["p_item": .string(item)]) }

    // MARK: Social

    public func friends() async throws -> FriendsOverview { try await api.rpc("friends_overview") }

    public func duels() async throws -> [Duel] { try await api.rpc("duels_mine") }

    public func duelCreate(friend: UUID?) async throws -> Duel {
        try await api.rpc("duel_create", ["p_friend": friend.map { .string($0.uuidString) } ?? .null])
    }

    public func duelCreate(friend: UUID?, settings: DuelSettings) async throws -> Duel {
        try await api.rpc("duel_create", [
            "p_friend": friend.map { .string($0.uuidString) } ?? .null,
            "p_count": .number(Double(settings.count)),
            "p_domains": settings.domains.isEmpty ? .null : .array(settings.domains.map(JSONValue.string)),
            "p_difficulty": .string(settings.difficulty.rawValue),
        ])
    }

    public func duelRematch(_ duel: UUID) async throws -> Duel {
        try await api.rpc("duel_rematch", ["p_duel": .string(duel.uuidString)])
    }

    public func friendProfile(_ friend: UUID) async throws -> FriendProfile {
        try await api.rpc("friend_profile", ["p_friend": .string(friend.uuidString)])
    }

    public func duelJoin(code: String) async throws -> Duel { try await api.rpc("duel_join", ["p_code": .string(code)]) }

    public func duelDecline(_ duel: UUID) async throws {
        try await api.rpcVoid("duel_decline", ["p_duel": .string(duel.uuidString)])
    }

    public func duelQuestion(duel: UUID, position: Int) async throws -> DailyQuestionResponse {
        try await api.rpc("duel_question", ["p_duel": .string(duel.uuidString), "p_position": .number(Double(position))])
    }

    public func duelAnswer(duel: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict {
        try await api.rpc("duel_answer", ["p_duel": .string(duel.uuidString), "p_position": .number(Double(position)),
                                          "p_given": given?.json ?? .null,
                                          "p_client_ms": clientMs.map { .number(Double($0)) } ?? .null])
    }

    public func duelResult(_ duel: UUID) async throws -> Duel { try await api.rpc("duel_result", ["p_duel": .string(duel.uuidString)]) }

    public func searchHandles(_ query: String) async throws -> [HandleSearchResult] {
        try await api.rpc("search_handles", ["p_query": .string(query)])
    }

    public func requestFriend(handle: String) async throws -> FriendRequestResult {
        try await api.rpc("friend_request", ["p_handle": .string(handle)])
    }

    public func respondFriend(friendship: UUID, accept: Bool) async throws {
        try await api.rpcVoid("friend_respond", ["p_friendship": .string(friendship.uuidString), "p_accept": .bool(accept)])
    }

    public func removeFriend(_ user: UUID) async throws {
        try await api.rpcVoid("friend_remove", ["p_user": .string(user.uuidString)])
    }

    public func blockUser(_ user: UUID) async throws {
        try await api.rpcVoid("friend_block", ["p_user": .string(user.uuidString)])
    }

    public func claimReferral(code: String, deviceHash: String) async throws -> ReferralClaimResult {
        try await api.rpc("referral_claim", ["p_code": .string(code), "p_device_hash": .string(deviceHash)])
    }

    public func referralOverview() async throws -> ReferralOverview { try await api.rpc("referral_overview") }
    public func leagues() async throws -> [LeagueSummary] { try await api.rpc("leagues_mine") }

    public func createLeague(name: String, period: LeaguePeriod) async throws -> LeagueStandings {
        try await api.rpc("league_create", ["p_name": .string(name), "p_period": .string(period.rawValue)])
    }

    public func joinLeague(code: String) async throws -> LeagueStandings {
        try await api.rpc("league_join", ["p_code": .string(code)])
    }

    public func leaveLeague(_ id: UUID) async throws {
        try await api.rpcVoid("league_leave", ["p_league": .string(id.uuidString)])
    }

    public func reportContent(kind: String, target: UUID, reason: String, note: String?) async throws {
        try await api.rpcVoid("report_content", ["p_kind": .string(kind), "p_target": .string(target.uuidString),
                                                 "p_reason": .string(reason), "p_note": note.map(JSONValue.string) ?? .null])
    }

    public func pushRegister(token: String, environment: String) async throws {
        try await api.rpcVoid("push_register", ["p_token": .string(token), "p_environment": .string(environment)])
    }

    public func pushUnregister(token: String) async throws {
        try await api.rpcVoid("push_unregister", ["p_token": .string(token)])
    }

    public func dataExport() async throws -> Data {
        let json: JSONValue = try await api.rpc("my_data_export")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(json)
    }

    public func createLeague(_ draft: LeagueDraft) async throws -> LeagueStandings {
        let domains = draft.settings.domains ?? []
        return try await api.rpc("league_create", [
            "p_name": .string(draft.name),
            "p_count": .number(Double(draft.settings.questionCount)),
            "p_domains": domains.isEmpty ? .null : .array(domains.map(JSONValue.string)),
            "p_difficulty": .string(draft.settings.difficulty),
            "p_duration": .string(draft.settings.duration),
            "p_start_today": .bool(draft.startToday),
            "p_max_members": .number(Double(draft.settings.maxMembers)),
        ])
    }

    public func leaguePreview(code: String) async throws -> LeaguePreview {
        try await api.rpc("league_preview", ["p_code": .string(code)])
    }

    public func leagueQuestion(league: UUID, position: Int) async throws -> DailyQuestionResponse {
        try await api.rpc("league_question", ["p_league": .string(league.uuidString), "p_position": .number(Double(position))])
    }

    public func leagueAnswer(league: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict {
        try await api.rpc("league_answer", ["p_league": .string(league.uuidString), "p_position": .number(Double(position)),
                                            "p_given": given?.json ?? .null,
                                            "p_client_ms": clientMs.map { .number(Double($0)) } ?? .null])
    }

    public func leagueDayResult(league: UUID) async throws -> LeagueDayResult {
        try await api.rpc("league_day_result", ["p_league": .string(league.uuidString)])
    }

    public func leagueNewSeason(league: UUID, startToday: Bool) async throws -> LeagueStandings {
        try await api.rpc("league_new_season", ["p_league": .string(league.uuidString), "p_start_today": .bool(startToday)])
    }

    public func leagueRegenerateCode(league: UUID) async throws -> String {
        let result: [String: String] = try await api.rpc("league_regenerate_code", ["p_league": .string(league.uuidString)])
        return result["invite_code"] ?? ""
    }

    public func leagueKick(league: UUID, user: UUID) async throws {
        try await api.rpcVoid("league_kick", ["p_league": .string(league.uuidString), "p_user": .string(user.uuidString)])
    }

    public func leagueStandings(_ id: UUID, offset: Int) async throws -> LeagueStandings {
        try await api.rpc("league_standings", ["p_league": .string(id.uuidString), "p_offset": .number(Double(offset))])
    }

    // MARK: Référentiel

    public func domains() async throws -> [DomainInfo] {
        try await api.select("domains", query: [URLQueryItem(name: "select", value: "id,name,daily_slot,sort"),
                                                URLQueryItem(name: "is_active", value: "eq.true"),
                                                URLQueryItem(name: "order", value: "sort")])
    }

    public func subdomains() async throws -> [SubdomainInfo] {
        try await api.select("subdomains", query: [URLQueryItem(name: "select", value: "id,domain_id,name,sort"),
                                                   URLQueryItem(name: "is_active", value: "eq.true"),
                                                   URLQueryItem(name: "order", value: "sort")])
    }
}

public extension GameService {
    /// Partie classée, adaptative, sur tout le domaine (ou multi-domaines).
    func playPack(mode: PlayMode, domain: String?, count: Int) async throws -> PlayPack {
        try await playPack(mode: mode, domain: domain, subdomains: [], count: count, ranked: true, level: .adaptive)
    }
}

public extension GameService {
    /// Par défaut (démo, service indisponible) : rien n'est envoyé.
    func trackEvents(_ events: [AppEvent]) async throws {}

    func correctionStart(session: UUID, test: Bool) async throws -> CorrectionStart {
        throw BackendError.server(status: 400, code: "correction_unavailable", message: "")
    }

    func adStatus() async throws -> AdStatus { AdStatus() }

    /// Par défaut (démo) : le duel de base.
    func duelCreate(friend: UUID?, settings: DuelSettings) async throws -> Duel { try await duelCreate(friend: friend) }

    func duelRematch(_ duel: UUID) async throws -> Duel {
        throw BackendError.server(status: 400, code: "duel_not_found", message: "")
    }

    func friendProfile(_ friend: UUID) async throws -> FriendProfile {
        throw BackendError.server(status: 400, code: "not_friends", message: "")
    }

    func reportContent(kind: String, target: UUID, reason: String, note: String?) async throws {}

    func dataExport() async throws -> Data {
        throw BackendError.server(status: 400, code: "export_unavailable", message: "")
    }

    func pushRegister(token: String, environment: String) async throws {}
    func pushUnregister(token: String) async throws {}

    // Ligues v2 : la démo garde les anciennes ligues.
    func createLeague(_ draft: LeagueDraft) async throws -> LeagueStandings {
        try await createLeague(name: draft.name, period: draft.settings.duration == "1w" ? .week : .month)
    }

    func leaguePreview(code: String) async throws -> LeaguePreview {
        throw BackendError.server(status: 400, code: "league_not_found", message: "")
    }

    func leagueQuestion(league: UUID, position: Int) async throws -> DailyQuestionResponse {
        throw BackendError.server(status: 400, code: "league_not_active", message: "")
    }

    func leagueAnswer(league: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict {
        throw BackendError.server(status: 400, code: "league_not_active", message: "")
    }

    func leagueDayResult(league: UUID) async throws -> LeagueDayResult {
        throw BackendError.server(status: 400, code: "league_not_active", message: "")
    }

    func leagueNewSeason(league: UUID, startToday: Bool) async throws -> LeagueStandings {
        throw BackendError.server(status: 400, code: "forbidden", message: "")
    }

    func leagueRegenerateCode(league: UUID) async throws -> String {
        throw BackendError.server(status: 400, code: "forbidden", message: "")
    }

    func leagueKick(league: UUID, user: UUID) async throws {
        throw BackendError.server(status: 400, code: "forbidden", message: "")
    }

    func adCan(_ kind: AdKind, ref: String?) async throws {
        throw BackendError.server(status: 400, code: "ad_unavailable", message: "")
    }

    func adClaim(_ kind: AdKind, ref: String?, test: Bool) async throws -> AdReward {
        throw BackendError.server(status: 400, code: "ad_unavailable", message: "")
    }

    func correctionSubmit(session: UUID, answers: [(UUID, GivenAnswer?)]) async throws -> CorrectionResult {
        throw BackendError.server(status: 400, code: "correction_unavailable", message: "")
    }
}
