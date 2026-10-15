package app.brainlix.core

/// Mesure le temps de réponse : de l'affichage complet de la question à la validation.
/// Horloge monotone (insensible aux changements d'heure). Le temps de lecture des explications n'est jamais compté.
class Stopwatch(private val now: () -> Long = System::nanoTime) {
    private var startedAt: Long? = null
    private var accumulated = 0L

    val isRunning: Boolean get() = startedAt != null

    fun start() {
        if (startedAt == null) startedAt = now()
    }

    /// Pause (app en arrière-plan) : le serveur garde sa propre horloge pour le 5 du jour.
    fun pause() {
        val started = startedAt ?: return
        accumulated += now() - started
        startedAt = null
    }

    fun reset() {
        startedAt = null
        accumulated = 0
    }

    val elapsedMilliseconds: Int
        get() = ((accumulated + (startedAt?.let { now() - it } ?: 0)) / 1_000_000).toInt()
}
