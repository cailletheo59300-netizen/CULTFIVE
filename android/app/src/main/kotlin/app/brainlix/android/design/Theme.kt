package app.brainlix.android.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable

/// Thème Brainlix : couleurs et typographie de l'iPhone. Material 3 n'est utilisé que pour quelques briques système
/// (champs de texte, feuilles), recolorées aux couleurs de la marque.
@Composable
fun BrainlixTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (dark) BrainlixColors.Dark else BrainlixColors.Light
    val type = BrainlixType()
    val scheme = (if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = colors.brand, onPrimary = colors.paperFixed,
        background = colors.paper, onBackground = colors.ink,
        surface = colors.paperRaised, onSurface = colors.ink, onSurfaceVariant = colors.inkSoft,
        outline = colors.hairline, error = colors.wrong,
    )
    CompositionLocalProvider(LocalBrainlixColors provides colors, LocalBrainlixType provides type) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

/// Accès court : `Brainlix.colors.brand`, `Brainlix.type.headline`.
object Brainlix {
    val colors: BrainlixColors @Composable @ReadOnlyComposable get() = LocalBrainlixColors.current
    val type: BrainlixType @Composable @ReadOnlyComposable get() = LocalBrainlixType.current
}
