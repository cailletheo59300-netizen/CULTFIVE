package app.brainlix.android

import android.app.Application
import app.brainlix.core.BackendConfig
import app.brainlix.core.GameService
import app.brainlix.core.LiveGameService
import app.brainlix.core.OfflineAttemptQueue
import app.brainlix.core.SupabaseApi
import java.io.File

/// Point d'entrée : un seul client serveur et une seule file hors ligne pour toute l'app.
class BrainlixApplication : Application() {
    lateinit var api: SupabaseApi
        private set
    lateinit var game: GameService
        private set
    lateinit var offlineQueue: OfflineAttemptQueue
        private set

    override fun onCreate() {
        super.onCreate()
        api = SupabaseApi(BackendConfig(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY), SessionPrefs(this))
        game = LiveGameService(api)
        offlineQueue = OfflineAttemptQueue(File(filesDir, "offline-attempts.json"))
    }
}
