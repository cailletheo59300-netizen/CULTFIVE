package app.brainlix.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.tooling.preview.Preview
import app.brainlix.android.design.Brainlix
import app.brainlix.android.design.BrainlixTheme
import app.brainlix.android.design.DomainTag
import app.brainlix.android.design.InkButton
import app.brainlix.android.design.LabelCaps
import app.brainlix.android.design.PopGradient
import app.brainlix.android.design.Radius
import app.brainlix.android.design.Space
import app.brainlix.android.design.SunButton
import app.brainlix.android.design.TextLink
import app.brainlix.android.design.popCard
import app.brainlix.core.BackendException
import app.brainlix.core.DailyStatus

/// Écran provisoire de l'étape 0 : vérifie la connexion invitée et l'état du 5 du jour, et montre les briques du design.
/// Il sera remplacé par l'accueil à l'étape 1.
@Composable
fun FoundationScreen(app: BrainlixApplication) {
    var status by remember { mutableStateOf<DailyStatus?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var attempt by remember { mutableIntStateOf(0) }
    LaunchedEffect(attempt) {
        error = null
        try {
            if (app.api.session == null) app.api.signInAnonymously()
            status = app.game.dailyStatus()
        } catch (e: BackendException) {
            error = e.message
        }
    }
    FoundationContent(status, error, onRetry = { attempt++ })
}

@Composable
private fun FoundationContent(status: DailyStatus?, error: String?, onRetry: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Brainlix.colors.paper)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Space.gutter, vertical = Space.l),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.l)).background(PopGradient).padding(Space.l)) {
            LabelCaps("Bientôt sur Android", color = Brainlix.colors.sun)
            Spacer(Modifier.height(Space.s))
            Text("Brainlix", style = Brainlix.type.display, color = Brainlix.colors.paperFixed)
            Text("5 questions par jour. Un Elo par domaine.", style = Brainlix.type.reading, color = Brainlix.colors.paperFixed)
        }
        Column(Modifier.popCard(), verticalArrangement = Arrangement.spacedBy(Space.s)) {
            LabelCaps("Serveur")
            when {
                error != null -> Text(error, style = Brainlix.type.body, color = Brainlix.colors.wrong)
                status == null -> Text("Connexion…", style = Brainlix.type.body, color = Brainlix.colors.inkSoft)
                else -> {
                    Text("5 du jour : ${status.state.name.lowercase()}", style = Brainlix.type.title3, color = Brainlix.colors.ink)
                    Text("Série : ${status.streak}", style = Brainlix.type.number, color = Brainlix.colors.ink)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
            listOf("history", "geography", "science", "music").forEach { DomainTag(it) }
        }
        InkButton("Réessayer", onClick = onRetry, arrow = true)
        SunButton("Bouton soleil", onClick = {})
        TextLink("Lien secondaire", onClick = {})
    }
}

@Preview
@Composable
private fun FoundationPreview() {
    BrainlixTheme { FoundationContent(null, null, onRetry = {}) }
}
