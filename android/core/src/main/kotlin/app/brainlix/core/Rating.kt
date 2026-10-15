package app.brainlix.core

import java.text.NumberFormat
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/// Elo affiché (serveur, 0054) : une progression séparée du niveau. Il part de 500 ; pendant les 20 premières réponses
/// classées du domaine (placement), +150 au plus par partie ; ensuite +30 au plus par partie, −40 (−80 dès 1 200).
/// Miroir de `Rating.swift`.
data class CoteCULT(val cote: Int, val answered: Int, val placed: Boolean = answered >= PLACEMENT_ANSWERS) {
    companion object {
        const val PLACEMENT_ANSWERS = 20
        const val PLACEMENT_GAMES = 2

        fun cote(level: Double): Int = (1000 + 17.37 * (level - 50)).roundToInt()

        /// Cote globale : moyenne des domaines pondérée par le nombre de réponses.
        fun global(skills: List<SkillSummary>): CoteCULT? {
            val played = skills.filter { it.answered > 0 }
            val total = played.sumOf { it.answered }
            if (total <= 0) return null
            val weighted = played.sumOf { it.rating.cote.toDouble() * it.answered } / total
            return CoteCULT(weighted.roundToInt(), total)
        }

        /// Elo global, « confirmé » dès qu'un domaine l'est.
        fun overall(skills: List<SkillSummary>): CoteCULT? {
            val all = global(skills) ?: return null
            return CoteCULT(all.cote, all.answered, skills.any { it.rating.placed })
        }

        /// « 1 342 » (espace fine insécable des milliers, à la française).
        fun format(value: Int): String = NumberFormat.getIntegerInstance(Locale.FRANCE).format(value)

        /// « +18 », « −7 », « = ».
        fun formatDelta(delta: Int): String = when {
            delta > 0 -> "+$delta"
            delta < 0 -> "−${-delta}"
            else -> "="
        }
    }

    /// Parties de placement jouées (0–2), à raison de 10 réponses par partie.
    val placementGames: Int get() = min(PLACEMENT_GAMES, answered / 10)
    /// Réponses classées du placement (0–20) et celles qui restent.
    val placementDone: Int get() = min(max(answered, 0), PLACEMENT_ANSWERS)
    val placementLeft: Int get() = PLACEMENT_ANSWERS - placementDone
    val rank: Rank get() = Rank.of(cote)
    /// « placement 7/20 ».
    val provisionalLabel: String get() = "placement $placementDone/$PLACEMENT_ANSWERS"
    val formatted: String get() = format(cote)

    /// Progression vers le rang suivant (0–1) et points restants.
    val toNextRank: Pair<Double, Int>?
        get() {
            val next = rank.next ?: return null
            val start = if (rank == Rank.CURIOUS) next.floor - 150 else rank.floor
            val progress = (cote - start).toDouble() / (next.floor - start)
            return progress.coerceIn(0.0, 1.0) to (next.floor - cote)
        }

    enum class Rank(val floor: Int, val label: String) {
        CURIOUS(Int.MIN_VALUE, "Curieux"),
        AMATEUR(600, "Amateur"),
        ENLIGHTENED(750, "Éclairé"),
        SCHOLAR(900, "Érudit"),
        EXPERT(1050, "Expert"),
        ENCYCLOPEDIA(1200, "Encyclopédie");

        val next: Rank? get() = entries.getOrNull(ordinal + 1)

        companion object {
            fun of(cote: Int): Rank = entries.lastOrNull { cote >= it.floor } ?: CURIOUS
        }
    }
}

/// Difficulté ressentie d'une question pour ce joueur, d'après ses chances de réussite estimées.
enum class RelativeDifficulty(val label: String) {
    EASY("Facile"), MEDIUM("Moyen"), HARD("Difficile"), VERY_HARD("Très difficile");

    companion object {
        fun of(expected: Double): RelativeDifficulty = when {
            expected >= 0.70 -> EASY
            expected >= 0.50 -> MEDIUM
            expected >= 0.35 -> HARD
            else -> VERY_HARD
        }
    }
}

/// Points d'une réponse (même règle que le serveur) : 50 + 100 × (1 − chances) + bonus de vitesse (≤ 30 sous 15 s).
object GamePoints {
    fun points(correct: Boolean, expected: Double?, responseMs: Int): Int {
        if (!correct) return 0
        val p = (expected ?: 0.5).coerceIn(0.0, 1.0)
        val speed = if (responseMs < 800) 0 else max(0, (30.0 * (15000 - responseMs) / 15000).roundToInt())
        return 50 + (100 * (1 - p)).roundToInt() + speed
    }
}

/// Ordre adaptatif dans une partie : après 3 bonnes réponses d'affilée, la question restante la plus dure ;
/// après 2 erreurs d'affilée, la plus accessible ; sinon l'ordre du serveur.
object AdaptiveOrder {
    fun nextIndex(remaining: List<Question>, correctStreak: Int, wrongStreak: Int): Int {
        if (remaining.size <= 1) return 0
        val chances = remaining.map { it.expected ?: 0.6 }
        if (correctStreak >= 3) return chances.indices.minBy { chances[it] }
        if (wrongStreak >= 2) return chances.indices.maxBy { chances[it] }
        return 0
    }
}
