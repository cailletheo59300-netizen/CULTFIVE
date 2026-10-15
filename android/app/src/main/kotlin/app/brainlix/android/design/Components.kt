package app.brainlix.android.design

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Briques de base, miroir de `ios/CultFive/DesignSystem/Components/Controls.swift`.

/// Action principale : pilule pleine, texte gras centré, ombre colorée, relief « jouet » qui s'écrase à l'appui.
@Composable
fun InkButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: Color = Brainlix.colors.brand,
    textColor: Color = Color.White,
    enabled: Boolean = true,
    arrow: Boolean = false,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val press by animateDpAsState(if (pressed) 3.dp else 0.dp, Motion.press(), label = "press")
    val lip = Color.Black.copy(alpha = 0.18f).compositeOver(fill)
    val shape = CircleShape
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 62.dp)
            .alpha(if (enabled) 1f else 0.35f)
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
    ) {
        // Liseré plus sombre sous la pilule.
        Box(Modifier.fillMaxWidth().height(58.dp).offset(y = 4.dp).background(lip, shape))
        Row(
            Modifier
                .fillMaxWidth()
                .height(58.dp)
                .offset(y = press)
                .shadow(if (enabled) 14.dp else 0.dp, shape, ambientColor = fill, spotColor = fill)
                .background(fill, shape)
                .padding(horizontal = Space.l),
            horizontalArrangement = Arrangement.spacedBy(Space.s, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text, style = Brainlix.type.button, color = textColor, maxLines = 1)
            if (arrow) Text("→", style = Brainlix.type.button, color = textColor, modifier = Modifier.offset(x = press))
        }
    }
}

/// Variante jaune soleil, pour les fonds violets.
@Composable
fun SunButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) =
    InkButton(text, onClick, modifier, fill = Brainlix.colors.sun, textColor = Brainlix.colors.inkFixed, enabled = enabled)

/// Variante blanche, pour les fonds colorés.
@Composable
fun InvertedButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) =
    InkButton(text, onClick, modifier, fill = Brainlix.colors.paperFixed, textColor = Brainlix.colors.brandDeep, enabled = enabled)

/// Aux couleurs d'un domaine.
@Composable
fun DomainButton(domainId: String, text: String, onClick: () -> Unit, modifier: Modifier = Modifier) =
    InkButton(text, onClick, modifier, fill = DomainPalette.color(domainId), textColor = DomainPalette.onColor(domainId))

/// Action secondaire : texte gras coloré, sans soulignement.
@Composable
fun TextLink(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Brainlix.colors.brand) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.96f else 1f, Motion.press(), label = "scale")
    Box(
        modifier
            .heightIn(min = 44.dp)
            .scale(scale)
            .alpha(if (pressed) 0.5f else 1f)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = Brainlix.type.callout.copy(fontWeight = Brainlix.type.title3.fontWeight), color = color)
    }
}

/// Carte ou ligne pressable : elle s'enfonce légèrement.
@Composable
fun Modifier.rowPress(onClick: () -> Unit): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, Motion.press(), label = "row")
    return this.scale(scale).clickable(interaction, indication = null, role = Role.Button, onClick = onClick)
}

/// Carte Pop : surface blanche très arrondie, ombre douce teintée.
@Composable
fun Modifier.popCard(padding: Dp = Space.m, radius: Dp = Radius.m, fill: Color = Brainlix.colors.paperRaised): Modifier {
    val shape = RoundedCornerShape(radius)
    val tint = Brainlix.colors.brandDeep.copy(alpha = 0.07f)
    return this
        .fillMaxWidth()
        .shadow(12.dp, shape, ambientColor = tint, spotColor = tint)
        .background(fill, shape)
        .padding(padding)
}

/// Filet de séparation arrondi.
@Composable
fun Hairline(modifier: Modifier = Modifier, color: Color = Brainlix.colors.hairline) {
    Box(modifier.fillMaxWidth().height(1.5.dp).background(color, CircleShape))
}

/// Pastille de domaine : pilule colorée, texte blanc.
@Composable
fun DomainTag(domainId: String, modifier: Modifier = Modifier, name: String? = null, onInk: Boolean = false) {
    val color = DomainPalette.color(domainId)
    Text(
        name ?: DomainPalette.fallbackName(domainId),
        style = Brainlix.type.label.copy(letterSpacing = TextStyle.Default.letterSpacing),
        color = if (onInk) color else DomainPalette.onColor(domainId),
        modifier = modifier
            .background(if (onInk) Color.White else color, CircleShape)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

/// Étiquette en petites capitales.
@Composable
fun LabelCaps(text: String, modifier: Modifier = Modifier, color: Color = Brainlix.colors.inkSoft) {
    Text(text.uppercase(), style = Brainlix.type.label, color = color, modifier = modifier)
}
