package app.brainlix.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

/// Façade typée de toutes les RPC Brainlix. Les écrans ne parlent qu'à cette interface. Miroir de `GameService.swift`.
/// Les implémentations par défaut sont celles de la démo (service sans serveur).
interface GameService {
    // Daily
    suspend fun dailyStatus(): DailyStatus
    suspend fun dailyStart(): DailyStart
    suspend fun dailyQuestion(run: String, position: Int): DailyQuestionResponse
    suspend fun dailyAnswer(run: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict
    suspend fun dailyResult(date: String?): DailyResult
    suspend fun dailyReview(date: String?): List<ReviewItem>
    suspend fun dailyHistory(days: Int): List<DailyHistoryEntry>

    // Objectifs et récap
    suspend fun quests(): QuestsOverview
    suspend fun weeklyRecap(weeks: Int): List<WeekRecap>

    // Jouer
    suspend fun onboardingPack(): PlayPack
    /// `subdomains` : sous-thèmes choisis (vide = tout le domaine). `ranked = false` : entraînement libre à difficulté `level`.
    suspend fun playPack(
        mode: PlayMode, domain: String?, subdomains: List<String> = emptyList(), count: Int,
        ranked: Boolean = true, level: PlayLevel = PlayLevel.ADAPTIVE,
    ): PlayPack
    suspend fun playSubmit(session: String, attempts: List<PlayAttempt>): PlaySubmitResult
    suspend fun spendHelp(session: String, question: String, kind: HelpKind): HelpContent
    /// Signalement d'une question (réponse fausse, ambiguë, faute, plus à jour, autre).
    suspend fun reportQuestion(question: String, reason: String, note: String?)
    /// Journal d'usage (ouverture, onboarding, partage…), stocké dans la base Brainlix uniquement.
    suspend fun trackEvents(events: List<AppEvent>) {}
    /// « Corrige tes erreurs » : ouverture après une pub vue (`test` : pubs de test, réservé aux admins).
    suspend fun correctionStart(session: String, test: Boolean): CorrectionStart =
        throw BackendException.server("correction_unavailable")
    suspend fun correctionSubmit(session: String, answers: List<Pair<String, GivenAnswer?>>): CorrectionResult =
        throw BackendException.server("correction_unavailable")
    /// Pubs récompensées : état du jour, vérification avant la pub, récompense après (vérifiée par le serveur).
    suspend fun adStatus(): AdStatus = AdStatus()
    suspend fun adCan(kind: AdKind, ref: String?): Unit = throw BackendException.server("ad_unavailable")
    suspend fun adClaim(kind: AdKind, ref: String?, test: Boolean): AdReward = throw BackendException.server("ad_unavailable")

    // Profil & progression
    suspend fun profile(): Profile
    suspend fun handleAvailable(handle: String): HandleAvailability
    suspend fun setHandle(handle: String): Profile
    suspend fun updateProfile(fields: Map<String, Any?>): Profile
    suspend fun completeOnboarding(level: String, interests: List<String>): Profile
    suspend fun setTimezone(identifier: String)
    suspend fun registerDevice(hash: String)
    suspend fun skills(): List<SkillSummary>
    suspend fun domainStats(domain: String): DomainStats
    suspend fun errors(): ErrorsOverview
    suspend fun achievements(): List<AchievementRef>
    suspend fun deleteAccount()

    // Coffres, arbre de Léon, tenue, trophées
    suspend fun progression(): ProgressionOverview
    suspend fun openChest(chest: String): ChestContents
    /// `clientId` rend l'appel idempotent (renvoi réseau).
    suspend fun feedTree(amount: Int, clientId: String): TreeFeedResult
    /// `item` null : retire l'objet de cet emplacement. Renvoie la tenue complète.
    suspend fun equip(slot: String, item: String?): Map<String, String>
    suspend fun trophies(): TrophiesOverview
    suspend fun shop(): ShopOverview
    suspend fun buy(item: String): ShopPurchase

    // Album de cartes et pass de saison (la démo n'a pas de collection)
    suspend fun albumOverview(): AlbumOverview = AlbumOverview.EMPTY
    /// `series` : un domaine ou « encyclo ». `clientId` rend l'ouverture idempotente (renvoi réseau).
    suspend fun albumOpenPack(series: String, pay: AlbumPayment, clientId: String): AlbumOpening =
        throw BackendException.server("album_unavailable")
    /// Fabrique une carte manquante. Renvoie le solde de neurones.
    suspend fun albumCraft(card: String): Int = throw BackendException.server("album_unavailable")
    /// Pose un jeton Prestige. Renvoie les jetons restants.
    suspend fun albumPrestige(card: String): Int = throw BackendException.server("album_unavailable")
    suspend fun albumSetHidden(card: String, state: String, hidden: Boolean) {}
    suspend fun albumDress(card: String, frame: String?, finish: String?, title: String?) {}
    suspend fun albumSetLook(back: String?, cover: String?) {}
    suspend fun albumAdmin(on: Boolean): AlbumOverview = AlbumOverview.EMPTY
    suspend fun albumAdminTool(tool: AlbumAdminTool, arg: String?): AlbumOverview = AlbumOverview.EMPTY
    suspend fun albumAdminState(card: String, state: String, on: Boolean) {}
    suspend fun seasonOverview(): SeasonOverview = SeasonOverview()
    suspend fun seasonClaim(tier: Int): Unit = throw BackendException.server("no_season")
    /// Coffres en bois gagnés après le palier 30. Renvoie le nombre récupéré.
    suspend fun seasonClaimExtra(): Int = 0

    // Social
    suspend fun friends(): FriendsOverview
    suspend fun duels(): List<Duel>
    /// `friend` null : défi ouvert, à partager par lien.
    suspend fun duelCreate(friend: String?): Duel
    /// Duel réglé (nombre de questions, domaines, difficulté).
    suspend fun duelCreate(friend: String?, settings: DuelSettings): Duel = duelCreate(friend)
    /// Revanche : même adversaire, mêmes réglages.
    suspend fun duelRematch(duel: String): Duel = throw BackendException.server("duel_not_found")
    /// Profil d'un ami et face-à-face.
    suspend fun friendProfile(friend: String): FriendProfile = throw BackendException.server("not_friends")
    suspend fun duelJoin(code: String): Duel
    suspend fun duelDecline(duel: String)
    suspend fun duelQuestion(duel: String, position: Int): DailyQuestionResponse
    suspend fun duelAnswer(duel: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict
    suspend fun duelResult(duel: String): Duel
    suspend fun searchHandles(query: String): List<HandleSearchResult>
    suspend fun requestFriend(handle: String): FriendRequestResult
    suspend fun respondFriend(friendship: String, accept: Boolean)
    suspend fun removeFriend(user: String)
    suspend fun blockUser(user: String)
    suspend fun claimReferral(code: String, deviceHash: String): ReferralClaimResult
    suspend fun referralOverview(): ReferralOverview
    suspend fun leagues(): List<LeagueSummary>
    suspend fun createLeague(name: String, period: LeaguePeriod): LeagueStandings
    suspend fun joinLeague(code: String): LeagueStandings
    suspend fun leaveLeague(id: String)
    suspend fun leagueStandings(id: String, offset: Int): LeagueStandings
    /// Signaler un joueur ou une ligue (kind : user · league ; reason : name · behavior · cheating · other).
    suspend fun reportContent(kind: String, target: String, reason: String, note: String?) {}
    /// Export de mes données personnelles (JSON lisible).
    suspend fun dataExport(): String = throw BackendException.server("export_unavailable")
    /// Réglages de l'app (version minimale, en numéro de build).
    suspend fun appSettings(): AppSettings = AppSettings(minBuild = 0)
    /// Rapport de plantage ou de blocage.
    suspend fun reportDiagnostic(kind: String, payload: JsonElement, appVersion: String, osVersion: String) {}
    /// Notifications push : jeton de l'appareil ; environment = production · sandbox.
    suspend fun pushRegister(token: String, environment: String) {}
    suspend fun pushUnregister(token: String) {}

    // Ligues v2 : quiz du jour propre à la ligue, saisons, aperçu avant de rejoindre (la démo garde les anciennes ligues).
    suspend fun createLeague(draft: LeagueDraft): LeagueStandings =
        createLeague(draft.name, if (draft.settings.duration == "1w") LeaguePeriod.WEEK else LeaguePeriod.MONTH)
    suspend fun leaguePreview(code: String): LeaguePreview = throw BackendException.server("league_not_found")
    suspend fun leagueQuestion(league: String, position: Int): DailyQuestionResponse = throw BackendException.server("league_not_active")
    suspend fun leagueAnswer(league: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict =
        throw BackendException.server("league_not_active")
    suspend fun leagueDayResult(league: String): LeagueDayResult = throw BackendException.server("league_not_active")
    suspend fun leagueNewSeason(league: String, startToday: Boolean): LeagueStandings = throw BackendException.server("forbidden")
    suspend fun leagueRegenerateCode(league: String): String = throw BackendException.server("forbidden")
    suspend fun leagueKick(league: String, user: String): Unit = throw BackendException.server("forbidden")

    // Référentiel
    suspend fun domains(): List<DomainInfo>
    suspend fun subdomains(): List<SubdomainInfo>
}

class LiveGameService(val api: SupabaseApi) : GameService {
    // Daily

    override suspend fun dailyStatus(): DailyStatus = api.rpc("daily_status")
    override suspend fun dailyStart(): DailyStart = api.rpc("daily_start")

    override suspend fun dailyQuestion(run: String, position: Int): DailyQuestionResponse =
        api.rpc("daily_question", mapOf("p_run" to run, "p_position" to position))

    override suspend fun dailyAnswer(run: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict =
        api.rpc("daily_answer", mapOf("p_run" to run, "p_position" to position, "p_given" to given?.json, "p_client_ms" to clientMs))

    override suspend fun dailyResult(date: String?): DailyResult = api.rpc("daily_result", mapOf("p_date" to date))
    override suspend fun dailyReview(date: String?): List<ReviewItem> = api.rpc("daily_review", mapOf("p_date" to date))
    override suspend fun dailyHistory(days: Int): List<DailyHistoryEntry> = api.rpc("daily_history", mapOf("p_days" to days))

    // Jouer

    override suspend fun onboardingPack(): PlayPack = api.rpc("onboarding_pack")

    override suspend fun playPack(
        mode: PlayMode, domain: String?, subdomains: List<String>, count: Int, ranked: Boolean, level: PlayLevel,
    ): PlayPack = api.rpc("play_pack", mapOf(
        "p_mode" to mode.serialName(), "p_domain" to domain, "p_subdomains" to subdomains.ifEmpty { null },
        "p_count" to count, "p_ranked" to ranked, "p_level" to level.serialName(),
    ))

    override suspend fun correctionStart(session: String, test: Boolean): CorrectionStart =
        api.rpc("play_correction_start", mapOf("p_session" to session, "p_via" to "ad", "p_test" to test))

    override suspend fun correctionSubmit(session: String, answers: List<Pair<String, GivenAnswer?>>): CorrectionResult =
        api.rpc("play_correction_submit", mapOf(
            "p_session" to session,
            "p_answers" to answers.map { (id, given) -> mapOf("question_id" to id, "given" to given?.json) },
        ))

    override suspend fun adStatus(): AdStatus = api.rpc("ad_status")

    override suspend fun adCan(kind: AdKind, ref: String?) =
        api.rpcVoid("ad_can", mapOf("p_kind" to kind.serialName(), "p_ref" to ref))

    override suspend fun adClaim(kind: AdKind, ref: String?, test: Boolean): AdReward =
        api.rpc("ad_claim", mapOf("p_kind" to kind.serialName(), "p_ref" to ref, "p_test" to test))

    override suspend fun trackEvents(events: List<AppEvent>) {
        if (events.isEmpty()) return
        api.rpcVoid("track_events", mapOf("p_events" to events.map { it.json }))
    }

    override suspend fun reportQuestion(question: String, reason: String, note: String?) =
        api.rpcVoid("report_question", mapOf("p_question" to question, "p_reason" to reason, "p_note" to note))

    override suspend fun playSubmit(session: String, attempts: List<PlayAttempt>): PlaySubmitResult =
        api.rpc("play_submit", mapOf(
            "p_session" to session,
            "p_attempts" to BrainlixJson.encodeToJsonElement(ListSerializer(PlayAttempt.serializer()), attempts),
        ))

    override suspend fun spendHelp(session: String, question: String, kind: HelpKind): HelpContent =
        api.rpc("play_spend_help", mapOf("p_session" to session, "p_question" to question, "p_kind" to kind.serialName()))

    // Profil

    override suspend fun profile(): Profile = api.rpc("profile_me")
    override suspend fun handleAvailable(handle: String): HandleAvailability = api.rpc("handle_available", mapOf("p_handle" to handle))
    override suspend fun setHandle(handle: String): Profile = api.rpc("set_handle", mapOf("p_handle" to handle))
    override suspend fun updateProfile(fields: Map<String, Any?>): Profile = api.rpc("profile_update", mapOf("p" to fields))

    override suspend fun completeOnboarding(level: String, interests: List<String>): Profile =
        api.rpc("complete_onboarding", mapOf("p_prior_level" to level, "p_interests" to interests))

    override suspend fun setTimezone(identifier: String) = api.rpcVoid("set_timezone", mapOf("p_tz" to identifier))
    override suspend fun registerDevice(hash: String) = api.rpcVoid("register_device", mapOf("p_device_hash" to hash))
    override suspend fun quests(): QuestsOverview = api.rpc("quests_overview")
    override suspend fun weeklyRecap(weeks: Int): List<WeekRecap> = api.rpc("weekly_recap", mapOf("p_weeks" to weeks))
    override suspend fun skills(): List<SkillSummary> = api.rpc("skills_overview")
    override suspend fun domainStats(domain: String): DomainStats = api.rpc("domain_stats", mapOf("p_domain" to domain))
    override suspend fun errors(): ErrorsOverview = api.rpc("errors_overview")
    override suspend fun achievements(): List<AchievementRef> = api.rpc("achievements_mine")
    override suspend fun deleteAccount() = api.rpcVoid("delete_account")

    // Coffres, arbre, tenue, trophées

    override suspend fun progression(): ProgressionOverview = api.rpc("progression_overview")
    override suspend fun openChest(chest: String): ChestContents = api.rpc("chest_open", mapOf("p_chest" to chest))

    override suspend fun feedTree(amount: Int, clientId: String): TreeFeedResult =
        api.rpc("tree_feed", mapOf("p_amount" to amount, "p_client_id" to clientId))

    override suspend fun equip(slot: String, item: String?): Map<String, String> =
        api.rpc("leon_equip", mapOf("p_slot" to slot, "p_item" to item))

    override suspend fun trophies(): TrophiesOverview = api.rpc("trophies_overview")
    override suspend fun shop(): ShopOverview = api.rpc("shop_overview")
    override suspend fun buy(item: String): ShopPurchase = api.rpc("shop_buy", mapOf("p_item" to item))

    // Social

    override suspend fun friends(): FriendsOverview = api.rpc("friends_overview")
    override suspend fun duels(): List<Duel> = api.rpc("duels_mine")
    override suspend fun duelCreate(friend: String?): Duel = api.rpc("duel_create", mapOf("p_friend" to friend))

    override suspend fun duelCreate(friend: String?, settings: DuelSettings): Duel = api.rpc("duel_create", mapOf(
        "p_friend" to friend,
        "p_count" to settings.count,
        "p_domains" to settings.domains.ifEmpty { null },
        "p_difficulty" to settings.difficulty.serialName(),
    ))

    override suspend fun duelRematch(duel: String): Duel = api.rpc("duel_rematch", mapOf("p_duel" to duel))
    override suspend fun friendProfile(friend: String): FriendProfile = api.rpc("friend_profile", mapOf("p_friend" to friend))
    override suspend fun duelJoin(code: String): Duel = api.rpc("duel_join", mapOf("p_code" to code))
    override suspend fun duelDecline(duel: String) = api.rpcVoid("duel_decline", mapOf("p_duel" to duel))

    override suspend fun duelQuestion(duel: String, position: Int): DailyQuestionResponse =
        api.rpc("duel_question", mapOf("p_duel" to duel, "p_position" to position))

    override suspend fun duelAnswer(duel: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict =
        api.rpc("duel_answer", mapOf("p_duel" to duel, "p_position" to position, "p_given" to given?.json, "p_client_ms" to clientMs))

    override suspend fun duelResult(duel: String): Duel = api.rpc("duel_result", mapOf("p_duel" to duel))
    override suspend fun searchHandles(query: String): List<HandleSearchResult> = api.rpc("search_handles", mapOf("p_query" to query))
    override suspend fun requestFriend(handle: String): FriendRequestResult = api.rpc("friend_request", mapOf("p_handle" to handle))

    override suspend fun respondFriend(friendship: String, accept: Boolean) =
        api.rpcVoid("friend_respond", mapOf("p_friendship" to friendship, "p_accept" to accept))

    override suspend fun removeFriend(user: String) = api.rpcVoid("friend_remove", mapOf("p_user" to user))
    override suspend fun blockUser(user: String) = api.rpcVoid("friend_block", mapOf("p_user" to user))

    override suspend fun claimReferral(code: String, deviceHash: String): ReferralClaimResult =
        api.rpc("referral_claim", mapOf("p_code" to code, "p_device_hash" to deviceHash))

    override suspend fun referralOverview(): ReferralOverview = api.rpc("referral_overview")
    override suspend fun leagues(): List<LeagueSummary> = api.rpc("leagues_mine")

    override suspend fun createLeague(name: String, period: LeaguePeriod): LeagueStandings =
        api.rpc("league_create", mapOf("p_name" to name, "p_period" to period.serialName()))

    override suspend fun joinLeague(code: String): LeagueStandings = api.rpc("league_join", mapOf("p_code" to code))
    override suspend fun leaveLeague(id: String) = api.rpcVoid("league_leave", mapOf("p_league" to id))

    override suspend fun reportContent(kind: String, target: String, reason: String, note: String?) =
        api.rpcVoid("report_content", mapOf("p_kind" to kind, "p_target" to target, "p_reason" to reason, "p_note" to note))

    override suspend fun appSettings(): AppSettings = api.rpc("app_settings")

    override suspend fun reportDiagnostic(kind: String, payload: JsonElement, appVersion: String, osVersion: String) =
        api.rpcVoid("report_diagnostic", mapOf("p_kind" to kind, "p_payload" to payload, "p_app_version" to appVersion,
            "p_os_version" to osVersion))

    override suspend fun pushRegister(token: String, environment: String) =
        api.rpcVoid("push_register", mapOf("p_token" to token, "p_environment" to environment))

    override suspend fun pushUnregister(token: String) = api.rpcVoid("push_unregister", mapOf("p_token" to token))

    override suspend fun dataExport(): String {
        val json: JsonElement = api.rpc("my_data_export")
        return prettyJson.encodeToString(JsonElement.serializer(), json)
    }

    override suspend fun createLeague(draft: LeagueDraft): LeagueStandings {
        val domains = draft.settings.domains.orEmpty()
        return api.rpc("league_create", mapOf(
            "p_name" to draft.name,
            "p_count" to draft.settings.questionCount,
            "p_domains" to domains.ifEmpty { null },
            "p_difficulty" to draft.settings.difficulty,
            "p_duration" to draft.settings.duration,
            "p_start_today" to draft.startToday,
            "p_max_members" to draft.settings.maxMembers,
        ))
    }

    override suspend fun leaguePreview(code: String): LeaguePreview = api.rpc("league_preview", mapOf("p_code" to code))

    override suspend fun leagueQuestion(league: String, position: Int): DailyQuestionResponse =
        api.rpc("league_question", mapOf("p_league" to league, "p_position" to position))

    override suspend fun leagueAnswer(league: String, position: Int, given: GivenAnswer?, clientMs: Int?): DailyVerdict =
        api.rpc("league_answer", mapOf("p_league" to league, "p_position" to position, "p_given" to given?.json,
            "p_client_ms" to clientMs))

    override suspend fun leagueDayResult(league: String): LeagueDayResult = api.rpc("league_day_result", mapOf("p_league" to league))

    override suspend fun leagueNewSeason(league: String, startToday: Boolean): LeagueStandings =
        api.rpc("league_new_season", mapOf("p_league" to league, "p_start_today" to startToday))

    override suspend fun leagueRegenerateCode(league: String): String {
        val result: Map<String, String> = api.rpc("league_regenerate_code", mapOf("p_league" to league))
        return result["invite_code"].orEmpty()
    }

    override suspend fun leagueKick(league: String, user: String) =
        api.rpcVoid("league_kick", mapOf("p_league" to league, "p_user" to user))

    override suspend fun leagueStandings(id: String, offset: Int): LeagueStandings =
        api.rpc("league_standings", mapOf("p_league" to id, "p_offset" to offset))

    // Album et pass

    @Serializable private data class Balance(val balance: Int)
    @Serializable private data class Tokens(val tokens: Int)
    @Serializable private data class Claimed(val claimed: Int)

    override suspend fun albumOverview(): AlbumOverview = api.rpc("album_overview")

    override suspend fun albumOpenPack(series: String, pay: AlbumPayment, clientId: String): AlbumOpening =
        api.rpc("album_open_pack", mapOf("p_series" to series, "p_pay" to pay.serialName(), "p_client_id" to clientId))

    override suspend fun albumCraft(card: String): Int = api.rpc("album_craft", mapOf("p_card" to card), Balance.serializer()).balance
    override suspend fun albumPrestige(card: String): Int = api.rpc("album_prestige", mapOf("p_card" to card), Tokens.serializer()).tokens

    override suspend fun albumSetHidden(card: String, state: String, hidden: Boolean) =
        api.rpcVoid("album_set_hidden", mapOf("p_card" to card, "p_state" to state, "p_hidden" to hidden))

    override suspend fun albumDress(card: String, frame: String?, finish: String?, title: String?) =
        api.rpcVoid("album_dress", mapOf("p_card" to card, "p_frame" to frame, "p_finish" to finish, "p_title" to title))

    override suspend fun albumSetLook(back: String?, cover: String?) =
        api.rpcVoid("album_set_look", mapOf("p_back" to back, "p_cover" to cover))

    override suspend fun albumAdmin(on: Boolean): AlbumOverview = api.rpc("album_admin", mapOf("p_on" to on))

    override suspend fun albumAdminTool(tool: AlbumAdminTool, arg: String?): AlbumOverview =
        api.rpc("album_admin_tool", mapOf("p_tool" to tool.serialName(), "p_arg" to arg))

    override suspend fun albumAdminState(card: String, state: String, on: Boolean) =
        api.rpcVoid("album_admin_state", mapOf("p_card" to card, "p_state" to state, "p_on" to on))

    override suspend fun seasonOverview(): SeasonOverview = api.rpc("season_overview")
    override suspend fun seasonClaim(tier: Int) = api.rpcVoid("season_claim", mapOf("p_tier" to tier))
    override suspend fun seasonClaimExtra(): Int = api.rpc("season_claim_extra", emptyMap(), Claimed.serializer()).claimed

    // Référentiel

    override suspend fun domains(): List<DomainInfo> = api.select(
        "domains",
        listOf("select" to "id,name,daily_slot,sort", "is_active" to "eq.true", "order" to "sort"),
        ListSerializer(DomainInfo.serializer()),
    )

    override suspend fun subdomains(): List<SubdomainInfo> = api.select(
        "subdomains",
        listOf("select" to "id,domain_id,name,sort", "is_active" to "eq.true", "order" to "sort"),
        ListSerializer(SubdomainInfo.serializer()),
    )

    private companion object {
        val prettyJson = Json { prettyPrint = true }
    }
}
