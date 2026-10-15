package app.brainlix.core

// Modèles des réponses du serveur, portés depuis `APIModels.swift` (mêmes clés snake_case, mêmes champs).
// Généré par un convertisseur puis relu : les décodeurs sur mesure sont dans ApiSpecial.kt.

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
enum class DailyState {
    @SerialName("available") AVAILABLE,
    @SerialName("in_progress") IN_PROGRESS,
    @SerialName("done") DONE;
}

@Serializable
data class DailyStatus(
    val date: String,
    val state: DailyState,
    @SerialName("run_id") val runId: String? = null,
    @SerialName("next_position") val nextPosition: Int? = null,
    val score: Int? = null,
    val answers: List<Boolean>,
    val streak: Int,
    @SerialName("streak_freezes") val streakFreezes: Int,
    @SerialName("seconds_until_next") val secondsUntilNext: Int,
)

@Serializable
data class DailyStart(
    @SerialName("run_id") val runId: String,
    val date: String,
    val status: String,
    @SerialName("next_position") val nextPosition: Int? = null,
    val total: Int,
)


@Serializable
data class DailyVerdict(
    val position: Int,
    @SerialName("is_correct") val isCorrect: Boolean? = null,
    val duplicate: Boolean? = null,
    @SerialName("counted_ms") val countedMs: Int? = null,
    @SerialName("error_transition") val errorTransition: String? = null,
    @SerialName("domain_id") val domainId: String? = null,
    @SerialName("domain_before") val domainBefore: Double? = null,
    @SerialName("domain_after") val domainAfter: Double? = null,
    val finished: Boolean? = null,
    val expired: Boolean? = null,
    val answer: CorrectAnswer? = null,
    val explanation: String? = null,
    val takeaway: String? = null,
    val source: String? = null,
)

@Serializable
data class Percentile(
    val top: Int? = null,
    val source: Source,
    val participants: Int,
) {
    @Serializable
    enum class Source {
        @SerialName("live") LIVE,
        @SerialName("estimate") ESTIMATE;
    }
}

@Serializable
data class AchievementRef(
    val id: String,
    val name: String,
    val description: String,
    @SerialName("unlocked_at") val unlockedAt: String? = null,
)

@Serializable
data class DailyResult(
    @SerialName("run_id") val runId: String,
    val date: String,
    val status: String,
    val score: Int,
    @SerialName("total_ms") val totalMs: Int,
    val xp: Int,
    val seeds: Int,
    val streak: Int,
    val achievements: List<AchievementRef>,
    val answers: List<Answer>,
    val percentile: Percentile? = null,
) {
    @Serializable
    data class Answer(
        val position: Int,
        @SerialName("is_correct") val isCorrect: Boolean,
        @SerialName("counted_ms") val countedMs: Int? = null,
        @SerialName("domain_id") val domainId: String,
        @SerialName("domain_before") val domainBefore: Double? = null,
        @SerialName("domain_after") val domainAfter: Double? = null,
    ) {
    }
}


@Serializable
data class DailyHistoryEntry(
    val date: String,
    val status: String,
    val score: Int? = null,
    @SerialName("total_ms") val totalMs: Int? = null,
    val rate: Int? = null,
    val percentile: Percentile? = null,
)

@Serializable
data class QuestsOverview(
    val day: Period,
    val week: Period,
    val newly: List<Reward>,
    val balance: Int? = null,
) {
    @Serializable
    data class Quest(
        val slot: Int,
        val label: String,
        val target: Int,
        val progress: Int,
        val done: Boolean,
        val xp: Int,
        val seeds: Int,
    )

    @Serializable
    data class Bonus(
        val xp: Int,
        val seeds: Int,
        val done: Boolean,
        val chest: String? = null,
    )

    @Serializable
    data class Period(
        @SerialName("period_start") val periodStart: String,
        @SerialName("ends_at") val endsAt: String,
        val quests: List<Quest>,
        val bonus: Bonus,
    ) {
    }

    @Serializable
    data class Reward(
        val label: String,
        val xp: Int,
        val seeds: Int,
        val bonus: Boolean? = null,
        val chest: String? = null,
    )
}

@Serializable
data class WeekRecap(
    @SerialName("week_start") val weekStart: String,
    val answers: Int,
    val correct: Int,
    val games: Int,
    val dailies: Int,
    @SerialName("daily_avg") val dailyAvg: Double? = null,
    @SerialName("errors_corrected") val errorsCorrected: Int,
    @SerialName("quests_done") val questsDone: Int,
    @SerialName("cote_moves") val coteMoves: List<CoteMove>,
) {
    @Serializable
    data class CoteMove(
        @SerialName("domain_id") val domainId: String,
        val delta: Int,
    ) {
    }
}

@Serializable
enum class PlayMode {
    @SerialName("quick") QUICK,
    @SerialName("training") TRAINING,
    @SerialName("surprise") SURPRISE,
    @SerialName("errors") ERRORS,
    @SerialName("challenge") CHALLENGE;
}

@Serializable
enum class PlayLevel {
    @SerialName("adaptive") ADAPTIVE,
    @SerialName("beginner") BEGINNER,
    @SerialName("intermediate") INTERMEDIATE,
    @SerialName("expert") EXPERT;
}

@Serializable
data class PlayPack(
    @SerialName("session_id") val sessionId: String,
    val mode: String? = null,
    val questions: List<Question>,
    val ranked: Boolean? = null,
    val level: String? = null,
)

@Serializable
data class PlayAttempt(
    @SerialName("client_attempt_id") val clientAttemptId: String,
    @SerialName("question_id") val questionId: String,
    val given: GivenAnswer? = null,
    @SerialName("response_ms") val responseMs: Int,
    @SerialName("first_given") val firstGiven: GivenAnswer? = null,
)

@Serializable
data class PlaySubmitResult(
    val recorded: Int,
    val correct: Int,
    val xp: Int,
    val seeds: Int,
    val corrected: List<String>,
    val results: List<Item>,
    val achievements: List<String>,
    val balance: Int,
    val points: Int? = null,
    val ratings: List<RatingChange>? = null,
    @SerialName("album_card") val albumCard: AlbumPull? = null,
) {
    @Serializable
    data class Item(
        @SerialName("question_id") val questionId: String,
        @SerialName("is_correct") val isCorrect: Boolean? = null,
        @SerialName("error_transition") val errorTransition: String? = null,
        @SerialName("domain_before") val domainBefore: Double? = null,
        @SerialName("domain_after") val domainAfter: Double? = null,
        val points: Int? = null,
    ) {
    }

    @Serializable
    data class RatingChange(
        @SerialName("domain_id") val domainId: String,
        @SerialName("cote_before") val coteBefore: Int,
        @SerialName("cote_after") val coteAfter: Int,
        val answered: Int,
        val placement: Int,
        val placed: Boolean,
    ) {
    }
}

@Serializable
enum class HelpKind {
    @SerialName("fifty_fifty") FIFTY_FIFTY,
    @SerialName("hint") HINT,
    @SerialName("context") CONTEXT,
    @SerialName("second_chance") SECOND_CHANCE;
}

@Serializable
data class HelpContent(
    val remove: List<String>? = null,
    val hint: String? = null,
    val context: String? = null,
    val balance: Int,
    @SerialName("ticket_used") val ticketUsed: Boolean? = null,
    @SerialName("tickets_left") val ticketsLeft: Int? = null,
)

@Serializable
data class Profile(
    val id: String,
    val handle: String,
    val avatar: JsonElement? = null,
    @SerialName("age_range") val ageRange: String? = null,
    val timezone: String,
    @SerialName("challenge_prior") val challengePrior: Double,
    val interests: List<String>,
    @SerialName("xp_total") val xpTotal: Int,
    val seeds: Int,
    val streak: Int,
    @SerialName("streak_best") val streakBest: Int,
    @SerialName("streak_freezes") val streakFreezes: Int,
    @SerialName("questions_answered") val questionsAnswered: Int,
    @SerialName("questions_correct") val questionsCorrect: Int,
    @SerialName("errors_corrected") val errorsCorrected: Int,
    @SerialName("active_errors") val activeErrors: Int,
    @SerialName("referral_code") val referralCode: String,
    @SerialName("notif_daily") val notifDaily: Boolean,
    @SerialName("notif_daily_time") val notifDailyTime: String,
    @SerialName("notif_reminder") val notifReminder: Boolean,
    @SerialName("notif_social") val notifSocial: Boolean? = null,
    @SerialName("notif_leagues") val notifLeagues: Boolean? = null,
    val onboarded: Boolean,
    @SerialName("is_anonymous") val isAnonymous: Boolean,
)

@Serializable
data class HandleAvailability(
    val available: Boolean,
    val reason: String? = null,
)

@Serializable
data class SkillSummary(
    @SerialName("domain_id") val domainId: String,
    val name: String,
    val level: Int,
    val reliability: Double,
    val answered: Int,
    val correct: Int,
    val cote: Int? = null,
    val placement: Int? = null,
    val placed: Boolean? = null,
)

@Serializable
data class DomainStats(
    @SerialName("domain_id") val domainId: String,
    val level: Int,
    val reliability: Double,
    val answered: Int,
    val correct: Int,
    @SerialName("avg_ms") val avgMs: Int? = null,
    @SerialName("concepts_mastered") val conceptsMastered: Int,
    val history: List<HistoryPoint>,
    val subdomains: List<Subdomain>,
    @SerialName("by_difficulty") val byDifficulty: List<DifficultyBand>,
    @SerialName("recent_errors") val recentErrors: List<RecentError>,
    val cote: Int? = null,
    val placement: Int? = null,
    val placed: Boolean? = null,
) {
    @Serializable
    data class Subdomain(
        val id: String,
        val name: String,
        val level: Int,
        val reliability: Double,
        val answered: Int,
        val correct: Int,
        val available: Int,
        val cote: Int? = null,
        val placed: Boolean? = null,
    )

    @Serializable
    data class HistoryPoint(
        val day: String,
        val level: Double,
    )

    @Serializable
    data class DifficultyBand(
        val band: String,
        val answered: Int,
        val correct: Int,
    )

    @Serializable
    data class RecentError(
        @SerialName("concept_id") val conceptId: String,
        val label: String,
        val state: String,
    ) {
    }
}

@Serializable
data class ErrorsOverview(
    val active: List<Item>,
    @SerialName("corrected_total") val correctedTotal: Int,
    @SerialName("mastered_total") val masteredTotal: Int,
) {
    @Serializable
    data class Item(
        @SerialName("concept_id") val conceptId: String,
        val label: String,
        @SerialName("domain_id") val domainId: String,
        val state: String,
        @SerialName("times_failed") val timesFailed: Int,
    ) {
    }
}

@Serializable
data class FriendToday(
    val score: Int? = null,
    @SerialName("total_ms") val totalMs: Int? = null,
    val status: String? = null,
    val answers: List<Boolean>? = null,
)

@Serializable
data class Friend(
    val id: String,
    val handle: String,
    val avatar: JsonElement? = null,
    val streak: Int,
    val today: FriendToday? = null,
)

@Serializable
data class FriendRequest(
    @SerialName("friendship_id") val friendshipId: String,
    @SerialName("id") val userId: String,
    val handle: String,
)

@Serializable
data class FriendsOverview(
    val friends: List<Friend>,
    val incoming: List<FriendRequest>,
    val outgoing: List<FriendRequest>,
)

@Serializable
data class HandleSearchResult(
    val id: String,
    val handle: String,
    val relation: String,
    val incoming: Boolean? = null,
)

@Serializable
data class FriendRequestResult(
    val status: String,
)

@Serializable
data class ReferralClaimResult(
    val status: String,
    val reason: String? = null,
    val seeds: Int? = null,
    val inviter: String? = null,
)

@Serializable
data class ReferralOverview(
    val code: String,
    val qualified: Int,
    val pending: Int,
    val tiers: List<Int>,
)

@Serializable
enum class LeaguePeriod {
    @SerialName("week") WEEK,
    @SerialName("month") MONTH;
}

@Serializable
data class LeagueSummary(
    val id: String,
    val name: String,
    val period: LeaguePeriod,
    val members: Int,
    @SerialName("invite_code") val inviteCode: String,
    val status: String? = null,
    @SerialName("my_rank") val myRank: Int? = null,
    @SerialName("days_left") val daysLeft: Int? = null,
    @SerialName("starts_in") val startsIn: Int? = null,
    @SerialName("question_count") val questionCount: Int? = null,
    @SerialName("today_state") val todayState: String? = null,
)

@Serializable
data class LeagueSettings(
    @SerialName("question_count") val questionCount: Int,
    val domains: List<String>? = null,
    val difficulty: String,
    val duration: String,
    @SerialName("max_members") val maxMembers: Int,
)

@Serializable
data class LeagueDraft(
    val name: String,
    val settings: LeagueSettings,
    val startToday: Boolean,
)

@Serializable
data class LeaguePreview(
    val found: Boolean,
    val error: String? = null,
    val code: String? = null,
    val name: String? = null,
    val owner: String? = null,
    val members: Int? = null,
    @SerialName("max_members") val maxMembers: Int? = null,
    @SerialName("is_member") val isMember: Boolean? = null,
    val status: String? = null,
    @SerialName("starts_on") val startsOn: String? = null,
    @SerialName("ends_on") val endsOn: String? = null,
    @SerialName("days_left") val daysLeft: Int? = null,
    val settings: LeagueSettings? = null,
)

@Serializable
data class LeagueDayResult(
    val day: String,
    val total: Int,
    val me: Me,
    @SerialName("my_answers") val myAnswers: List<Duel.Mark>,
    val members: List<Member>? = null,
) {
    @Serializable
    data class Me(
        val answered: Int,
        val score: Int,
        @SerialName("total_ms") val totalMs: Int,
    ) {
    }

    @Serializable
    data class Member(
        val id: String,
        val handle: String,
        @SerialName("is_me") val isMe: Boolean,
        val answered: Int,
        val score: Int,
        @SerialName("total_ms") val totalMs: Int,
    ) {
    }
}

@Serializable
data class LeagueStandings(
    val id: String,
    val name: String,
    val period: LeaguePeriod,
    @SerialName("invite_code") val inviteCode: String,
    @SerialName("is_owner") val isOwner: Boolean,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String,
    val standings: List<Row>,
    val podium: Podium? = null,
    @SerialName("my_reward") val myReward: Reward? = null,
    val season: Int? = null,
    @SerialName("current_season") val currentSeason: Int? = null,
    @SerialName("has_previous") val hasPrevious: Boolean? = null,
    val status: String? = null,
    val timezone: String? = null,
    @SerialName("total_days") val totalDays: Int? = null,
    @SerialName("day_index") val dayIndex: Int? = null,
    @SerialName("days_left") val daysLeft: Int? = null,
    @SerialName("starts_in") val startsIn: Int? = null,
    @SerialName("ends_at") val endsAt: String? = null,
    val members: Int? = null,
    val settings: LeagueSettings? = null,
    @SerialName("my_today") val myToday: Today? = null,
) {
    @Serializable
    data class Row(
        val rank: Int,
        val id: String,
        val handle: String,
        val points: Int,
        val days: Int,
        @SerialName("total_ms") val totalMs: Int,
        @SerialName("is_me") val isMe: Boolean,
        @SerialName("is_owner") val isOwner: Boolean? = null,
    ) {
    }

    @Serializable
    data class Today(
        val answered: Int,
        val score: Int,
        val total: Int,
        val state: String,
    )

    @Serializable
    data class Podium(
        @SerialName("min_players") val minPlayers: Int,
        @SerialName("min_days") val minDays: Int,
        @SerialName("active_players") val activePlayers: Int,
    ) {
    }

    @Serializable
    data class Reward(
        val tier: ChestTier,
        val place: Int,
    )
}

@Serializable
data class DomainInfo(
    val id: String,
    val name: String,
    @SerialName("daily_slot") val dailySlot: String? = null,
    val sort: Int,
)

@Serializable
data class SubdomainInfo(
    val id: String,
    @SerialName("domain_id") val domainId: String,
    val name: String,
    val sort: Int,
)

@Serializable
data class Duel(
    val id: String,
    val code: String,
    val status: String,
    @SerialName("expires_at") val expiresAt: String? = null,
    @SerialName("i_am_challenger") val iAmChallenger: Boolean,
    val opponent: Opponent? = null,
    val me: Mine,
    @SerialName("my_turn") val myTurn: Boolean,
    val winner: String? = null,
    @SerialName("my_answers") val myAnswers: List<Mark>? = null,
    @SerialName("their_answers") val theirAnswers: List<Mark>? = null,
    val total: Int? = null,
    val domains: List<String>? = null,
    val difficulty: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
) {
    @Serializable
    data class Opponent(
        val id: String? = null,
        val handle: String? = null,
        val answered: Int,
        val score: Int? = null,
        @SerialName("total_ms") val totalMs: Int? = null,
    ) {
    }

    @Serializable
    data class Mine(
        val answered: Int,
        val score: Int,
        @SerialName("total_ms") val totalMs: Int,
    ) {
    }

    @Serializable
    data class Mark(
        val position: Int,
        @SerialName("is_correct") val isCorrect: Boolean? = null,
        @SerialName("counted_ms") val countedMs: Int? = null,
    ) {
    }
}

@Serializable
enum class DuelDifficulty {
    @SerialName("auto") AUTO,
    @SerialName("easy") EASY,
    @SerialName("medium") MEDIUM,
    @SerialName("hard") HARD;
}

@Serializable
data class DuelSettings(
    val count: Int,
    val domains: List<String>,
    val difficulty: DuelDifficulty,
)

@Serializable
data class FriendProfile(
    val id: String,
    val handle: String,
    val streak: Int,
    @SerialName("streak_best") val streakBest: Int,
    @SerialName("xp_total") val xpTotal: Int,
    val cote: Int? = null,
    @SerialName("cote_placed") val cotePlaced: Boolean,
    val today: FriendToday? = null,
    @SerialName("head_to_head") val headToHead: HeadToHead,
    val duels: List<Duel>,
) {
    @Serializable
    data class HeadToHead(
        val played: Int,
        val wins: Int,
        val losses: Int,
        val draws: Int,
        val questions: Int,
        @SerialName("my_rate") val myRate: Int? = null,
        @SerialName("their_rate") val theirRate: Int? = null,
        val streak: Streak? = null,
        @SerialName("my_best") val myBest: Best? = null,
    ) {
        @Serializable
        data class Streak(
            val who: String,
            val count: Int,
        )

        @Serializable
        data class Best(
            val score: Int,
            val total: Int,
        )

    }
}



@Serializable
enum class ChestTier {
    @SerialName("wood") WOOD,
    @SerialName("silver") SILVER,
    @SerialName("gold") GOLD,
    @SerialName("savant") SAVANT;
}

@Serializable
data class ChestRef(
    val id: String,
    val tier: ChestTier,
    val source: String,
    val ref: String? = null,
)

@Serializable
data class ChestItem(
    val id: String,
    val name: String,
    val slot: String,
)

@Serializable
data class ChestContents(
    val tier: ChestTier,
    val seeds: Int,
    val tickets: Tickets,
    val joker: Boolean,
    val item: ChestItem? = null,
    val balance: Int? = null,
    @SerialName("final_tier") val finalTier: ChestTier? = null,
    val upgrades: Int? = null,
    @SerialName("bonus_item") val bonusItem: ChestItem? = null,
    @SerialName("pack_tickets") val packTickets: Int? = null,
    val card: AlbumPull? = null,
    @SerialName("prestige_token") val prestigeToken: Boolean? = null,
) {
    @Serializable
    data class Tickets(
        @SerialName("fifty_fifty") val fiftyFifty: Int,
        val hint: Int,
    ) {
    }
}

@Serializable
data class TreeState(
    val points: Int,
    val stage: Int,
    @SerialName("stage_name") val stageName: String,
    val fruits: Int,
    @SerialName("next_at") val nextAt: Int? = null,
    val max: Int,
    val complete: Boolean,
)

@Serializable
data class LeonItem(
    val id: String,
    val name: String,
    val slot: String,
    val rarity: String,
    val owned: Boolean,
    val equipped: Boolean,
    val price: Int? = null,
    @SerialName("unlock_stage") val unlockStage: Int? = null,
)

@Serializable
data class ShopOverview(
    val featured: List<Featured>,
    @SerialName("resets_at") val resetsAt: String? = null,
    val balance: Int,
) {
    @Serializable
    data class Featured(
        val id: String,
        val price: Int,
        val original: Int,
    )
}

@Serializable
data class ShopPurchase(
    val bought: Boolean,
    val item: String,
    val price: Int? = null,
    val balance: Int,
)

@Serializable
data class HelpTickets(
    @SerialName("fifty_fifty") val fiftyFifty: Int,
    val hint: Int,
)

@Serializable
data class ProgressionOverview(
    val xp: Int,
    val level: Int,
    val seeds: Int,
    @SerialName("streak_freezes") val streakFreezes: Int,
    val tree: TreeState,
    val chests: List<ChestRef>,
    val tickets: HelpTickets,
    val outfit: Map<String, String>,
    val items: List<LeonItem>,
    @SerialName("best_form") val bestForm: String? = null,
)

@Serializable
data class TreeFeedResult(
    val fed: Int,
    @SerialName("new_chests") val newChests: Int,
    @SerialName("new_items") val newItems: List<ChestItem>,
    val tree: TreeState,
    val balance: Int,
)

@Serializable
data class TrophiesOverview(
    val exploits: List<Exploit>,
    val mastery: List<Mastery>,
) {
    @Serializable
    data class Exploit(
        val id: String,
        val name: String,
        val description: String,
        val chest: ChestTier? = null,
        @SerialName("unlocked_at") val unlockedAt: String? = null,
    ) {
    }

    @Serializable
    data class Mastery(
        @SerialName("domain_id") val domainId: String,
        val name: String,
        val placed: Boolean,
        val cote: Int? = null,
        val tier: String? = null,
        val next: Next? = null,
    ) {
        @Serializable
        data class Next(
            val tier: String,
            val cote: Int,
        )

    }
}


@Serializable
data class CorrectionStart(
    @SerialName("question_ids") val questionIds: List<String>,
    val ranked: Boolean,
)

@Serializable
data class CorrectionResult(
    val corrected: Int,
    val total: Int,
    val refunds: List<Refund>,
) {
    @Serializable
    data class Refund(
        @SerialName("domain_id") val domainId: String,
        @SerialName("cote_refund") val coteRefund: Int,
        @SerialName("cote_after") val coteAfter: Int,
    ) {
    }
}

@Serializable
enum class AdKind {
    @SerialName("double_seeds") DOUBLE_SEEDS,
    @SerialName("boost_chest") BOOST_CHEST,
    @SerialName("free_chest") FREE_CHEST,
    @SerialName("free_pack") FREE_PACK,
    @SerialName("streak_rescue") STREAK_RESCUE,
    @SerialName("correction") CORRECTION;
}


@Serializable
data class AdReward(
    val seeds: Int? = null,
    @SerialName("chest_id") val chestId: String? = null,
    val boosted: Boolean? = null,
    val streak: Int? = null,
    val balance: Int? = null,
)

@Serializable
data class AppSettings(
    @SerialName("min_build") val minBuild: Int,
)
