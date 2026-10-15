package app.brainlix.android.design

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

// Tokens du design system, miroir de `ios/CultFive/DesignSystem/Tokens.swift` (voir docs/DESIGN_SYSTEM.md).
// Toute couleur de l'app passe par ici.

@Immutable
data class BrainlixColors(
    /// Fond d'écran : blanc très légèrement lavande (les cartes blanches s'en détachent).
    val paper: Color,
    /// Surface des cartes.
    val paperRaised: Color,
    val ink: Color,
    val inkSoft: Color,
    val hairline: Color,
    /// Couleur de marque : violet électrique. Boutons principaux, écrans de moment fort.
    val brand: Color,
    val correct: Color,
    val wrong: Color,
    val isDark: Boolean,
) {
    val brandDeep = Color(0xFF3A1FB8)
    /// Accent « soleil » : score, surlignages sur fond violet. Toujours avec du texte foncé.
    val sun = Color(0xFFFFD23F)
    /// Joues de Léon, confettis.
    val blush = Color(0xFFFF8FB1)
    /// Encre et papier fixes (ne s'inversent pas en mode sombre).
    val inkFixed = Color(0xFF1A1830)
    val paperFixed = Color(0xFFFFFFFF)

    companion object {
        val Light = BrainlixColors(
            paper = Color(0xFFF6F5FB), paperRaised = Color(0xFFFFFFFF), ink = Color(0xFF1A1830), inkSoft = Color(0xFF6E6B85),
            hairline = Color(0xFFE9E7F2), brand = Color(0xFF6A4CFF), correct = Color(0xFF12B76A), wrong = Color(0xFFFF4D5E),
            isDark = false,
        )
        val Dark = BrainlixColors(
            paper = Color(0xFF0E0D16), paperRaised = Color(0xFF1C1A2A), ink = Color(0xFFF4F3FA), inkSoft = Color(0xFFA3A0B8),
            hairline = Color(0xFF2C2940), brand = Color(0xFF8469FF), correct = Color(0xFF3DDC97), wrong = Color(0xFFFF6B7A),
            isDark = true,
        )
    }
}

val LocalBrainlixColors = staticCompositionLocalOf { BrainlixColors.Light }

/// Dégradé des moments forts (résultat, accueil, cartes de partage).
val PopGradient = Brush.linearGradient(listOf(Color(0xFF7B5CFF), Color(0xFF3A1FB8)))

/// Couleurs de domaine : vives, une par domaine. Les grandes surfaces colorées portent un texte `onColor`.
object DomainPalette {
    fun color(domainId: String): Color = Color(0xFF000000 or hex(domainId))

    /// Texte lisible sur l'aplat du domaine.
    fun onColor(domainId: String): Color = if (domainId == "music") Color(0xFF1A1830) else Color.White

    fun hex(domainId: String): Long = when (domainId) {
        "calc" -> 0x2F6BFF
        "french" -> 0xF0588F
        "geography" -> 0x0CA678
        "history" -> 0xF76707
        "science" -> 0x1098AD
        "logic" -> 0x845EF7
        "arts" -> 0xD6336C
        "sport" -> 0xE5383B
        "cinema" -> 0x5F3DC4
        "music" -> 0xFCC419
        "tech" -> 0x1C7ED6
        "nature" -> 0x37B24D
        else -> 0x6E6B85
    }

    /// Libellé court de secours si le référentiel n'est pas encore chargé.
    fun fallbackName(domainId: String): String = when (domainId) {
        "calc" -> "Calcul"
        "french" -> "Français"
        "geography" -> "Géographie"
        "history" -> "Histoire"
        "science" -> "Sciences"
        "logic" -> "Logique"
        "arts" -> "Arts & culture"
        "sport" -> "Sport"
        "cinema" -> "Cinéma"
        "music" -> "Musique"
        "tech" -> "Technologie"
        "nature" -> "Nature & animaux"
        else -> domainId.replaceFirstChar { it.uppercase() }
    }
}

object Space {
    val xs = 4.dp
    val s = 8.dp
    val m = 16.dp
    val l = 24.dp
    val xl = 40.dp
    val xxl = 64.dp
    /// Marge latérale des écrans.
    val gutter = 20.dp
}

/// Rayons : tout est arrondi, rien n'est carré.
object Radius {
    val s = 14.dp
    val m = 20.dp
    val l = 28.dp
}

/// Ressorts (équivalents des `Motion` iPhone : réponse ≈ raideur, amortissement identique).
object Motion {
    fun <T> press() = spring<T>(dampingRatio = 0.6f, stiffness = 800f)
    fun <T> standard() = spring<T>(dampingRatio = 0.78f, stiffness = Spring.StiffnessMediumLow)
    fun <T> moment() = spring<T>(dampingRatio = 0.68f, stiffness = 130f)
    /// Rebond franc (verdict, apparition d'un chiffre).
    fun <T> bounce() = spring<T>(dampingRatio = 0.5f, stiffness = 250f)
}
