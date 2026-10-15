package app.brainlix.core

import java.text.NumberFormat
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/// Niveau d'XP (activité), distinct du niveau de connaissance.
/// XP cumulée pour atteindre le niveau L : 50 · L · (L − 1) → L2 = 100, L3 = 300, L4 = 600, L5 = 1 000…
data class XPLevel(val level: Int, val xpIntoLevel: Int, val xpForNextLevel: Int) {
    val progress: Double get() = if (xpForNextLevel == 0) 0.0 else xpIntoLevel.toDouble() / xpForNextLevel

    companion object {
        fun threshold(level: Int): Int = 50 * level * (level - 1)

        fun of(totalXP: Int): XPLevel {
            val xp = max(totalXP, 0)
            var level = ((1 + sqrt(1 + 4 * xp.toDouble() / 50)) / 2).toInt()
            while (threshold(level + 1) <= xp) level++
            while (level > 1 && threshold(level) > xp) level--
            level = max(level, 1)
            val start = threshold(level)
            return XPLevel(level, xp - start, threshold(level + 1) - start)
        }
    }
}

/// Fiabilité statistique d'un niveau, traduite en mots (jamais un faux pourcentage de précision).
enum class Reliability(val label: String) {
    REFINING("à affiner"), FAIR("correcte"), SOLID("solide");

    companion object {
        fun of(value: Double): Reliability = when {
            value < 0.35 -> REFINING
            value < 0.65 -> FAIR
            else -> SOLID
        }
    }
}

object NumberFormatFr {
    /// Affiche un nombre de réponse (« 42,195 », « 10 000 ») selon les conventions françaises.
    fun display(value: Double, decimals: Int? = null): String {
        val f = NumberFormat.getNumberInstance(Locale.FRANCE)
        f.maximumFractionDigits = decimals ?: 6
        f.minimumFractionDigits = 0
        return f.format(value)
    }
}

object DurationFormat {
    /// « 01:43 » (mm:ss), ou « 1:02:03 » au-delà d'une heure.
    fun clock(milliseconds: Int): String {
        val total = max(milliseconds, 0) / 1000
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
    }

    /// « 4,2 s » pour un temps moyen.
    fun seconds(milliseconds: Int): String =
        NumberFormatFr.display(((milliseconds / 1000.0) * 10).roundToInt() / 10.0, 1) + " s"

    /// « 3 h 12 », « 12 min » : compte à rebours jusqu'au prochain 5 du jour.
    fun countdown(seconds: Int): String {
        val s = max(seconds, 0)
        val h = s / 3600
        val m = (s % 3600) / 60
        return if (h > 0) "$h h ${"%02d".format(m)}" else "${max(m, 1)} min"
    }
}

/// État du pavé numérique interne (questions de calcul) : saisie contrôlée, sans erreur de format.
/// Le texte canonique utilise « . » ; l'affichage utilise la virgule et groupe les milliers.
data class NumericEntry(
    val maxDecimals: Int = 3,
    val allowNegative: Boolean = false,
    val maxDigits: Int = 9,
    val raw: String = "",
    val isNegative: Boolean = false,
) {
    val isEmpty: Boolean get() = raw.isEmpty()
    private val digitCount: Int get() = raw.count { it.isDigit() }
    private val decimalPart: String? get() = raw.indexOf('.').takeIf { it >= 0 }?.let { raw.substring(it + 1) }

    fun appendDigit(digit: Int): NumericEntry {
        if (digit !in 0..9 || digitCount >= maxDigits) return this
        decimalPart?.let { if (it.length >= maxDecimals) return this }
        return copy(raw = if (raw == "0") digit.toString() else raw + digit)
    }

    fun appendDecimalSeparator(): NumericEntry {
        if (maxDecimals <= 0 || raw.contains('.')) return this
        return copy(raw = if (raw.isEmpty()) "0." else "$raw.")
    }

    fun toggleSign(): NumericEntry = if (allowNegative) copy(isNegative = !isNegative) else this

    fun backspace(): NumericEntry = if (raw.isEmpty()) copy(isNegative = false) else copy(raw = raw.dropLast(1))

    fun clear(): NumericEntry = copy(raw = "", isNegative = false)

    /// Valeur saisie, ou null si rien de valide.
    val value: Double?
        get() {
            val text = raw.removeSuffix(".")
            val number = text.takeIf { it.isNotEmpty() }?.toDoubleOrNull() ?: return null
            return if (isNegative) -number else number
        }

    /// Texte affiché : « 3 600 », « −12,5 », « 0, ».
    fun display(decimalSeparator: String = ",", groupingSeparator: String = " "): String {
        if (raw.isEmpty()) return if (isNegative) "−" else ""
        val parts = raw.split(".")
        val integer = parts[0]
        val grouped = StringBuilder()
        integer.reversed().forEachIndexed { index, c ->
            if (index > 0 && index % 3 == 0) grouped.append(groupingSeparator.reversed())
            grouped.append(c)
        }
        var result = grouped.reverse().toString()
        if (parts.size > 1) result += decimalSeparator + parts[1]
        return (if (isNegative) "−" else "") + result
    }
}
