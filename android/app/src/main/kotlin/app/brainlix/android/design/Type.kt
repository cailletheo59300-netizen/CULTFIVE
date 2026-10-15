package app.brainlix.android.design

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.brainlix.android.R

// Voix Pop : police arrondie (Nunito, l'équivalent de SF Pro Rounded), grasse et généreuse. Chiffres en « heavy ».
// Les tailles sont en sp : elles suivent la taille de texte choisie dans Android.

@OptIn(ExperimentalTextApi::class)
private fun nunito(weight: FontWeight) =
    Font(R.font.nunito, weight, variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)))

val Nunito = FontFamily(
    nunito(FontWeight.Normal), nunito(FontWeight.Medium), nunito(FontWeight.SemiBold),
    nunito(FontWeight.Bold), nunito(FontWeight.ExtraBold), nunito(FontWeight.Black),
)

private fun style(size: Int, weight: FontWeight, line: Float = 1.25f) =
    TextStyle(fontFamily = Nunito, fontWeight = weight, fontSize = size.sp, lineHeight = (size * line).sp)

@Immutable
data class BrainlixType(
    /// Titres d'écran et grands moments.
    val display: TextStyle = style(34, FontWeight.Black, 1.15f),
    /// Énoncé d'une question.
    val question: TextStyle = style(22, FontWeight.ExtraBold),
    /// Titres de section.
    val headline: TextStyle = style(22, FontWeight.ExtraBold),
    /// Titres secondaires (listes de domaines, noms).
    val title3: TextStyle = style(20, FontWeight.ExtraBold),
    val body: TextStyle = style(17, FontWeight.Normal, 1.3f),
    /// Texte de lecture (explications) : un peu plus de corps.
    val reading: TextStyle = style(17, FontWeight.Medium, 1.4f),
    val callout: TextStyle = style(16, FontWeight.Medium),
    val footnote: TextStyle = style(13, FontWeight.Medium),
    /// Étiquettes courtes en capitales (catégorie, rubrique).
    val label: TextStyle = style(12, FontWeight.Black).copy(letterSpacing = 0.07.em),
    /// Chiffres alignés.
    val number: TextStyle = style(17, FontWeight.ExtraBold).copy(fontFeatureSettings = "tnum"),
    /// Texte des boutons principaux.
    val button: TextStyle = style(17, FontWeight.Black),
) {
    /// Chiffre géant (score, niveau), arrondi et très gras.
    fun numeral(size: Int, weight: FontWeight = FontWeight.Black) =
        style(size, weight, 1.05f).copy(fontFeatureSettings = "tnum")
}

val LocalBrainlixType = staticCompositionLocalOf { BrainlixType() }
