package app.brainlix.core

import kotlinx.serialization.serializer
import kotlin.math.roundToInt

// Propriétés calculées des modèles (mêmes règles que les `var … { }` de APIModels.swift).

/// Nom côté serveur d'une valeur d'énumération (son @SerialName), pour les paramètres des appels.
inline fun <reified E : Enum<E>> E.serialName(): String = serializer<E>().descriptor.getElementName(ordinal)

val DailyVerdict.reveal: Reveal?
    get() {
        val answer = answer ?: return null
        val explanation = explanation ?: return null
        return Reveal(answer, explanation, takeaway, source)
    }

val DailyHistoryEntry.top: Int? get() = percentile?.top

val QuestsOverview.Period.doneCount: Int get() = quests.count { it.done }

/// % de bonnes réponses de la semaine.
val WeekRecap.rate: Int? get() = if (answers > 0) (correct.toDouble() / answers * 100).roundToInt() else null
val WeekRecap.isEmpty: Boolean get() = answers == 0 && dailies == 0

val PlaySubmitResult.RatingChange.delta: Int get() = coteAfter - coteBefore

val HelpKind.cost: Int
    get() = when (this) {
        HelpKind.FIFTY_FIFTY -> 15
        HelpKind.HINT -> 10
        HelpKind.CONTEXT -> 5
        HelpKind.SECOND_CHANCE -> 15
    }

val SkillSummary.rating: CoteCULT get() = CoteCULT(cote ?: CoteCULT.cote(level.toDouble()), answered, placed ?: (answered >= CoteCULT.PLACEMENT_ANSWERS))
val DomainStats.rating: CoteCULT get() = CoteCULT(cote ?: CoteCULT.cote(level.toDouble()), answered, placed ?: (answered >= CoteCULT.PLACEMENT_ANSWERS))
val DomainStats.Subdomain.rating: CoteCULT get() = CoteCULT(cote ?: CoteCULT.cote(level.toDouble()), answered, placed ?: (answered >= CoteCULT.PLACEMENT_ANSWERS))

val Duel.isFinished: Boolean get() = status == "finished"
val Duel.questionCount: Int get() = total ?: 5

val DuelDifficulty.title: String
    get() = when (this) {
        DuelDifficulty.AUTO -> "Auto"
        DuelDifficulty.EASY -> "Facile"
        DuelDifficulty.MEDIUM -> "Moyen"
        DuelDifficulty.HARD -> "Difficile"
    }

val ChestTier.title: String get() = ChestName.title(serialName())

/// D'où vient le coffre, en mots.
val ChestRef.origin: String
    get() = when (source) {
        "quests_day" -> "Tous les défis du jour"
        "quests_week" -> "Tous les défis de la semaine"
        "level" -> ref?.let { "Niveau $it" } ?: "Nouveau niveau"
        "trophy" -> "Trophée"
        "referral" -> "Parrainage"
        "league" -> "Podium de ta ligue"
        "welcome" -> "Bienvenue dans la nouvelle version"
        "ad" -> "Coffre offert"
        else -> "Récompense"
    }

/// Rang final du coffre, montées comprises.
val ChestContents.reachedTier: ChestTier get() = finalTier ?: tier

/// Le ticket « indice » sert aussi de Seconde chance.
fun HelpTickets.count(kind: HelpKind): Int = when (kind) {
    HelpKind.FIFTY_FIFTY -> fiftyFifty
    HelpKind.HINT, HelpKind.SECOND_CHANCE -> hint
    HelpKind.CONTEXT -> 0
}
