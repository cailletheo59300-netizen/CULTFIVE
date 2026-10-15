package app.brainlix.android

import android.content.Context
import app.brainlix.core.AuthSession
import app.brainlix.core.BrainlixJson
import app.brainlix.core.SessionStore

/// Session de connexion, dans le stockage privé de l'app (exclu des sauvegardes : voir res/xml/backup_rules.xml).
/// Équivalent de `KeychainSessionStore.swift`.
class SessionPrefs(context: Context) : SessionStore {
    private val prefs = context.getSharedPreferences("brainlix_session", Context.MODE_PRIVATE)

    override fun load(): AuthSession? = prefs.getString(KEY, null)?.let {
        runCatching { BrainlixJson.decodeFromString(AuthSession.serializer(), it) }.getOrNull()
    }

    override fun save(session: AuthSession?) {
        prefs.edit().apply {
            if (session == null) remove(KEY) else putString(KEY, BrainlixJson.encodeToString(AuthSession.serializer(), session))
        }.apply()
    }

    private companion object {
        const val KEY = "session"
    }
}
