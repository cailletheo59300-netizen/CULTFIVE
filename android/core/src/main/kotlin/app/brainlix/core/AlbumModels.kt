package app.brainlix.core

// Modèles des réponses du serveur, portés depuis `Album.swift` (mêmes clés snake_case, mêmes champs).
// Généré par un convertisseur puis relu : les décodeurs sur mesure sont dans ApiSpecial.kt.

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
data class AlbumOverview(
    val admin: Boolean,
    @SerialName("can_admin") val canAdmin: Boolean,
    val neurones: Int,
    val tickets: Int,
    val tokens: Int,
    @SerialName("gold_packs") val goldPacks: Int,
    @SerialName("gold_available") val goldAvailable: Boolean,
    @SerialName("forced_rarity") val forcedRarity: String? = null,
    val back: String,
    val cover: String,
    val cosmetics: List<String>,
    val cards: List<Card>,
) {
    companion object {
        /// Album vide (démo, service indisponible). Les clés restent obligatoires au décodage, comme sur iPhone.
        val EMPTY = AlbumOverview(
            admin = false, canAdmin = false, neurones = 0, tickets = 0, tokens = 0, goldPacks = 0, goldAvailable = true,
            back = "classique", cover = "classique", cosmetics = emptyList(), cards = emptyList(),
        )
    }

    @Serializable
    data class Card(
        val id: String,
        val copies: Int,
        val shiny: Boolean,
        val prestige: Boolean,
        val masterpiece: Boolean,
        val stars: Int,
        val hidden: List<String>,
        val frame: String? = null,
        val finish: String? = null,
        val title: String? = null,
    )
}

@Serializable
data class AlbumPull(
    val card: String,
    val rarity: String,
    val outcome: Outcome,
    val neurones: Int? = null,
) {
    @Serializable
    enum class Outcome {
        @SerialName("new") NEW,
        @SerialName("shiny") SHINY,
        @SerialName("neurones") NEURONES;
    }
}

@Serializable
data class AlbumOpening(
    val id: String,
    val series: String,
    val gold: Boolean,
    val pulls: List<AlbumPull>,
    val balance: Int? = null,
)

@Serializable
enum class AlbumPayment {
    @SerialName("neurones") NEURONES,
    @SerialName("ticket") TICKET,
    @SerialName("gold") GOLD,
    @SerialName("gold_pass") GOLD_PASS;
}

@Serializable
enum class AlbumAdminTool {
    @SerialName("own_all") OWN_ALL,
    @SerialName("own_all_shiny") OWN_ALL_SHINY,
    @SerialName("empty") EMPTY,
    @SerialName("force") FORCE;
}

/// Sans saison en cours, le serveur ne renvoie que `season: null` : tout le reste a une valeur par défaut.
@Serializable
data class SeasonOverview(
    val season: Season? = null,
    val points: Int = 0,
    val tier: Int = 0,
    @SerialName("tier_points") val tierPoints: Int = 150,
    val tiers: Int = 30,
    val rewards: List<Reward> = emptyList(),
    @SerialName("extra_chests") val extraChests: Extra? = null,
    @SerialName("points_rules") val pointsRules: Rules = Rules(),
    val missions: List<Mission> = emptyList(),
) {
    @Serializable
    data class Season(
        val id: Int,
        val name: String,
        @SerialName("starts_on") val startsOn: String,
        @SerialName("ends_on") val endsOn: String,
    )

    @Serializable
    data class Reward(
        val tier: Int,
        val kind: String,
        val label: String,
        val icon: String,
        val claimed: Boolean,
    )

    @Serializable
    data class Extra(
        val earned: Int,
        val claimed: Int,
    )

    @Serializable
    data class Rules(
        val day: Int = 15,
        @SerialName("day_bonus") val dayBonus: Int = 15,
        val week: Int = 40,
        @SerialName("week_bonus") val weekBonus: Int = 60,
        val mission: Int = 75,
    )

    @Serializable
    data class Mission(
        val slot: Int,
        val label: String,
        val progress: Int,
        val target: Int,
        val done: Boolean,
    )
}
