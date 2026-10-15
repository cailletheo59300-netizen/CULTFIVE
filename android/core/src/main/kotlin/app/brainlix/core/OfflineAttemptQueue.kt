package app.brainlix.core

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File

/// File persistante des tentatives du mode Jouer non encore synchronisées (hors-ligne, crash, fermeture).
/// Idempotente côté serveur (client_attempt_id) : on peut renvoyer sans risque de double comptage.
/// Le Daily n'y passe jamais : il est validé question par question, en ligne. Miroir de `OfflineAttemptQueue.swift`.
class OfflineAttemptQueue(
    /// null : file en mémoire (tests, prévisualisations).
    private val file: File?,
) {
    @Serializable
    data class Batch(@SerialName("sessionId") val sessionId: String, val attempts: List<PlayAttempt>)

    private val mutex = Mutex()
    private var batches: List<Batch> = file?.takeIf { it.exists() }?.let {
        runCatching { BrainlixJson.decodeFromString(ListSerializer(Batch.serializer()), it.readText()) }.getOrNull()
    } ?: emptyList()

    suspend fun pendingCount(): Int = mutex.withLock { batches.sumOf { it.attempts.size } }

    suspend fun enqueue(session: String, attempts: List<PlayAttempt>) {
        if (attempts.isEmpty()) return
        mutex.withLock {
            val index = batches.indexOfFirst { it.sessionId == session }
            batches = if (index >= 0) {
                val known = batches[index].attempts.map { it.clientAttemptId }.toSet()
                val merged = batches[index].copy(attempts = batches[index].attempts + attempts.filter { it.clientAttemptId !in known })
                batches.toMutableList().also { it[index] = merged }
            } else {
                batches + Batch(session, attempts)
            }
            persist()
        }
    }

    /// Envoie chaque lot ; ceux qui échouent restent en file. Renvoie le nombre de lots envoyés.
    suspend fun drain(send: suspend (session: String, attempts: List<PlayAttempt>) -> Unit): Int = mutex.withLock {
        var sent = 0
        for (batch in batches) {
            try {
                send(batch.sessionId, batch.attempts)
            } catch (e: Exception) {
                continue
            }
            batches = batches.filter { it.sessionId != batch.sessionId }
            sent++
            persist()
        }
        sent
    }

    suspend fun remove(session: String) = mutex.withLock {
        batches = batches.filter { it.sessionId != session }
        persist()
    }

    private fun persist() {
        val file = file ?: return
        runCatching {
            val tmp = File(file.parentFile, file.name + ".tmp")
            tmp.writeText(BrainlixJson.encodeToString(ListSerializer(Batch.serializer()), batches))
            if (!tmp.renameTo(file)) { file.delete(); tmp.renameTo(file) }
        }
    }
}
