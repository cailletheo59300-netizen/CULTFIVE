import Foundation

/// Façade typée de toutes les RPC CULT FIVE. Les écrans ne parlent qu'à ce protocole.
public protocol GameService: Sendable {
    // Daily
    func dailyStatus() async throws -> DailyStatus
    func dailyStart() async throws -> DailyStart
    func dailyQuestion(run: UUID, position: Int) async throws -> DailyQuestionResponse
    func dailyAnswer(run: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict
    func dailyResult(date: String?) async throws -> DailyResult
    func dailyReview(date: String?) async throws -> [ReviewItem]
    func dailyHistory(days: Int) async throws -> [DailyHistoryEntry]

    // Jouer
    func onboardingPack() async throws -> PlayPack
    func playPack(mode: PlayMode, domain: String?, subdomain: String?, count: Int) async throws -> PlayPack
    func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult
    func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent

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

    // Social
    func friends() async throws -> FriendsOverview
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

    public func playPack(mode: PlayMode, domain: String?, subdomain: String?, count: Int) async throws -> PlayPack {
        try await api.rpc("play_pack", ["p_mode": .string(mode.rawValue), "p_domain": optional(domain),
                                        "p_subdomain": optional(subdomain), "p_count": .number(Double(count))])
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

    public func skills() async throws -> [SkillSummary] { try await api.rpc("skills_overview") }

    public func domainStats(_ domain: String) async throws -> DomainStats {
        try await api.rpc("domain_stats", ["p_domain": .string(domain)])
    }

    public func errors() async throws -> ErrorsOverview { try await api.rpc("errors_overview") }
    public func achievements() async throws -> [AchievementRef] { try await api.rpc("achievements_mine") }
    public func deleteAccount() async throws { try await api.rpcVoid("delete_account") }

    // MARK: Social

    public func friends() async throws -> FriendsOverview { try await api.rpc("friends_overview") }

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
                                                   URLQueryItem(name: "order", value: "sort")])
    }
}
