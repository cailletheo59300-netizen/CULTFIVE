package app.brainlix.core

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.serializer
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

// Client Supabase minimal (Auth + RPC PostgREST). Miroir de `SupabaseAPI.swift` (D-011) : même contrat, mêmes erreurs.

data class BackendConfig(val url: String, val anonKey: String)

@Serializable
data class AuthSession(
    val accessToken: String,
    val refreshToken: String,
    /// Expiration, en secondes depuis 1970.
    val expiresAt: Long,
    val userId: String,
    val isAnonymous: Boolean,
    val email: String? = null,
)

interface SessionStore {
    fun load(): AuthSession?
    fun save(session: AuthSession?)
}

class InMemorySessionStore(private var session: AuthSession? = null) : SessionStore {
    @Synchronized override fun load(): AuthSession? = session
    @Synchronized override fun save(session: AuthSession?) { this.session = session }
}

data class HttpRequest(val url: String, val method: String, val headers: Map<String, String>, val body: String?)
data class HttpResponse(val status: Int, val body: String)

/// Transport HTTP remplaçable (tests sans réseau). Les erreurs réseau sont des `IOException`.
fun interface HttpTransport {
    suspend fun send(request: HttpRequest): HttpResponse
}

class OkHttpTransport(
    private val client: OkHttpClient = OkHttpClient.Builder().callTimeout(20, TimeUnit.SECONDS).build(),
) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val builder = Request.Builder().url(request.url)
        request.headers.forEach { (name, value) -> builder.header(name, value) }
        val body = request.body?.toRequestBody("application/json".toMediaType())
        builder.method(request.method, body ?: if (request.method == "POST" || request.method == "PUT") ByteArray(0).toRequestBody() else null)
        val call = client.newCall(builder.build())
        return suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) = continuation.resumeWithException(e)
                override fun onResponse(call: Call, response: Response) {
                    val result = response.use { HttpResponse(it.code, it.body?.string().orEmpty()) }
                    continuation.resume(result)
                }
            })
        }
    }
}

sealed class BackendException(message: String) : Exception(message) {
    data object NotAuthenticated : BackendException("Session expirée. Reconnecte-toi.")
    data object Offline : BackendException("Pas de connexion. Réessaie dans un instant.")
    /// `code` : code métier renvoyé par nos RPC (ex. `daily_closed`) ou code d'erreur Auth (ex. `email_exists`).
    data class Server(val status: Int, val serverCode: String, val serverMessage: String) :
        BackendException(humanMessage(serverCode) ?: serverMessage)
    data class Decoding(val detail: String) : BackendException("Réponse inattendue du serveur.")

    val code: String? get() = (this as? Server)?.serverCode

    companion object {
        /// Messages lisibles pour les codes métier connus.
        fun humanMessage(code: String): String? = when (code) {
            "handle_taken" -> "Ce pseudo est déjà pris."
            "handle_invalid" -> "3 à 20 caractères : lettres, chiffres ou _."
            "handle_change_too_soon" -> "Tu pourras rechanger de pseudo dans quelques jours."
            "user_not_found" -> "Aucun joueur avec ce pseudo."
            "rate_limited" -> "Doucement ! Réessaie un peu plus tard."
            "correction_limit" -> "Tu as déjà corrigé 3 parties aujourd'hui. Reviens demain !"
            "invalid_count", "invalid_difficulty", "invalid_duration", "invalid_max_members" -> "Réglages invalides."
            "invalid_name" -> "Le nom doit faire entre 3 et 40 caractères."
            "name_not_allowed" -> "Ce nom n'est pas autorisé. Choisis-en un autre."
            "export_unavailable" -> "Export indisponible pour l'instant."
            "league_not_active" -> "Le quiz de la ligue n'est pas ouvert aujourd'hui."
            "league_not_finished" -> "La ligue n'est pas encore terminée."
            "league_out_of_order", "league_not_served" -> "Question déjà passée. Rouvre le quiz."
            "not_friends" -> "Vous n'êtes plus amis."
            "not_enough_questions" -> "Pas assez de questions pour ces réglages : élargis les domaines ou la difficulté."
            "ad_pending" -> "La pub n'a pas encore été confirmée. Réessaie dans un instant."
            "ad_limit" -> "Plus de récompense de ce type pour aujourd'hui. Reviens demain !"
            "ad_already_used" -> "Récompense déjà obtenue."
            "ad_expired", "correction_unavailable" -> "Trop tard pour cette récompense."
            "ad_required" -> "Mets à jour l'app pour corriger tes erreurs."
            "ad_unavailable" -> "Aucune pub disponible pour l'instant. Réessaie un peu plus tard."
            "nothing_to_double" -> "Pas de neurones à doubler sur cette partie."
            "streak_not_rescuable" -> "Cette série ne peut plus être sauvée."
            "chest_opened" -> "Ce coffre est déjà ouvert."
            "album_unavailable" -> "L'album n'est pas disponible pour l'instant."
            "no_ticket" -> "Plus de ticket de pochette."
            "no_gold_pack" -> "Plus de pochette dorée à ouvrir."
            "gold_weekly_limit" -> "Une seule pochette dorée par semaine : reviens lundi."
            "card_owned" -> "Tu as déjà cette carte."
            "card_not_owned" -> "Tu n'as pas encore cette carte."
            "already_prestige" -> "Cette carte a déjà son jeton Prestige."
            "no_token" -> "Aucun jeton Prestige pour l'instant."
            "no_season" -> "Aucune saison en cours."
            "tier_not_reached" -> "Ce palier n'est pas encore atteint."
            "already_claimed" -> "Récompense déjà récupérée."
            "correction_expired" -> "Trop tard pour corriger cette partie : la correction se fait juste après."
            "correction_done" -> "Cette partie a déjà été corrigée."
            "nothing_to_correct" -> "Aucune erreur à corriger : bravo !"
            "banned" -> "Ce compte est suspendu. Si c'est une erreur, écris-nous depuis la page d'aide de brainlix.site."
            "insufficient_seeds" -> "Pas assez de neurones."
            "help_unavailable" -> "Aide indisponible pour cette question."
            "tree_complete" -> "L'arbre de Léon est complet."
            "chest_not_found" -> "Coffre introuvable."
            "item_not_owned" -> "Tu n'as pas encore cet objet."
            "item_not_for_sale" -> "Cet objet ne se vend pas : il se gagne."
            "league_not_found" -> "Ligue introuvable."
            "league_full" -> "Cette ligue est complète."
            "forbidden" -> "Réservé au créateur de la ligue."
            "too_many_leagues" -> "Tu fais déjà partie de 10 ligues."
            "referral_code_invalid" -> "Code d'invitation inconnu."
            "referral_already_claimed" -> "Invitation déjà utilisée."
            "referral_requires_account" -> "Crée ton compte pour profiter de l'invitation."
            "email_exists", "email_address_exists" -> "Cet e-mail a déjà un compte. Connecte-toi."
            "otp_expired", "invalid_otp" -> "Code invalide ou expiré."
            else -> null
        }

        fun server(code: String) = Server(400, code, "")
    }
}

class SupabaseApi(
    val config: BackendConfig,
    private val store: SessionStore,
    private val transport: HttpTransport = OkHttpTransport(),
    /// Horloge en secondes (tests).
    private val now: () -> Long = { System.currentTimeMillis() / 1000 },
) {
    companion object {
        /// Version des types de réponses comprise par l'app (en-tête « x-brainlix-types »).
        const val ANSWER_TYPES_VERSION = "2"

        fun parseError(status: Int, body: String): BackendException {
            val json = runCatching { BrainlixJson.parseToJsonElement(body) }.getOrNull()
            // PostgREST : {"code":"P0001","message":"daily_closed"} — nos RPC lèvent des codes métier dans `message`.
            // Auth : {"error_code":"email_exists","msg":"…"} ou {"error":"invalid_grant","error_description":"…"}.
            val message = json["message"].stringValue ?: json["msg"].stringValue ?: json["error_description"].stringValue ?: body
            val pgCode = json["code"].stringValue
            val errorCode = json["error_code"].stringValue
            val error = json["error"].stringValue
            val code = when {
                errorCode != null -> errorCode
                pgCode == "P0001" || pgCode == "28000" || pgCode == "42501" -> message.split(':', ' ').first()
                error != null -> error
                else -> pgCode ?: "http_$status"
            }
            if (code == "not_authenticated") return BackendException.NotAuthenticated
            return BackendException.Server(status, code, message)
        }
    }

    @Volatile var session: AuthSession? = store.load()
        private set

    val userId: String? get() = session?.userId
    val isAnonymous: Boolean get() = session?.isAnonymous ?: true

    private val refreshMutex = Mutex()

    /// Signalement des échecs techniques (réseau, serveur en erreur, réponse illisible) pour le suivi de fiabilité.
    /// Les refus métier (« ligue introuvable »…) n'en sont pas.
    var errorHandler: ((function: String, code: String) -> Unit)? = null

    // Auth

    /// Découverte sans inscription : compte anonyme Supabase, lié plus tard à Google, Apple ou un e-mail.
    suspend fun signInAnonymously(): AuthSession =
        adopt(send("auth/v1/signup", method = "POST", body = jsonOf("data" to emptyMap<String, Any>()), auth = AuthMode.ANON_KEY))

    /// Connexion par jeton d'identité (Google ou Apple). Session anonyme : l'identité lui est liée (aucune perte de progression) ;
    /// si ce compte existe déjà, on se connecte simplement dessus.
    suspend fun signInWithIdToken(provider: String, idToken: String, nonce: String?): AuthSession {
        val base = buildMap<String, Any?> {
            put("provider", provider)
            put("id_token", idToken)
            nonce?.let { put("nonce", it) }
        }
        val query = listOf("grant_type" to "id_token")
        if (session?.isAnonymous == true) {
            try {
                return adopt(send("auth/v1/token", query, "POST", (base + ("link_identity" to true)).toJsonElement() as JsonObject, AuthMode.USER))
            } catch (e: BackendException.Server) {
                if (e.serverCode != "identity_already_exists" && e.serverCode != "identity_already_linked") throw e
            }
        }
        return adopt(send("auth/v1/token", query, "POST", base.toJsonElement() as JsonObject, AuthMode.ANON_KEY))
    }

    /// Envoie un code à 6 chiffres par e-mail. Session anonyme : conversion du compte courant (changement d'e-mail).
    suspend fun sendEmailCode(email: String, convertAnonymous: Boolean) {
        if (convertAnonymous && session?.isAnonymous == true) {
            send("auth/v1/user", method = "PUT", body = jsonOf("email" to email), auth = AuthMode.USER)
        } else {
            send("auth/v1/otp", method = "POST", body = jsonOf("email" to email, "create_user" to true), auth = AuthMode.ANON_KEY)
        }
    }

    suspend fun verifyEmailCode(email: String, code: String, isConversion: Boolean): AuthSession {
        val body = jsonOf("type" to if (isConversion) "email_change" else "email", "email" to email, "token" to code)
        val data = send("auth/v1/verify", method = "POST", body = body, auth = if (isConversion) AuthMode.USER else AuthMode.ANON_KEY)
        runCatching { return adopt(data) }
        // Conversion : la réponse peut ne contenir que l'utilisateur ; on rafraîchit pour obtenir un jeton à jour.
        return refresh(force = true)
    }

    suspend fun signOut() {
        if (session != null) runCatching { send("auth/v1/logout", method = "POST", body = null, auth = AuthMode.USER) }
        clearLocalSession()
    }

    /// Oublie la session locale sans appel réseau (compte supprimé côté serveur).
    fun clearLocalSession() {
        session = null
        store.save(null)
    }

    // RPC

    private fun report(function: String, error: Throwable) {
        if (function == "track_events" || function == "report_diagnostic") return
        val handler = errorHandler ?: return
        when (error) {
            is BackendException.Offline -> handler(function, "offline")
            is BackendException.Decoding -> handler(function, "decoding")
            is BackendException.Server -> if (error.status >= 500 || error.status == 0) {
                handler(function, error.serverCode.ifEmpty { "http_${error.status}" })
            }
            else -> Unit
        }
    }

    suspend fun <T> rpc(function: String, params: Map<String, Any?>, deserializer: DeserializationStrategy<T>): T {
        val data = try {
            send("rest/v1/rpc/$function", method = "POST", body = params.toJsonElement() as JsonObject, auth = AuthMode.USER)
        } catch (e: Exception) {
            report(function, e)
            throw e
        }
        return try {
            BrainlixJson.decodeFromString(deserializer, data)
        } catch (e: Exception) {
            val failure = BackendException.Decoding("$function: ${e.message}")
            report(function, failure)
            throw failure
        }
    }

    suspend inline fun <reified T> rpc(function: String, params: Map<String, Any?> = emptyMap()): T =
        rpc(function, params, serializer<T>())

    suspend fun rpcVoid(function: String, params: Map<String, Any?> = emptyMap()) {
        try {
            send("rest/v1/rpc/$function", method = "POST", body = params.toJsonElement() as JsonObject, auth = AuthMode.USER)
        } catch (e: Exception) {
            report(function, e)
            throw e
        }
    }

    /// Lecture de tables de référentiel (RLS : lecture publique).
    suspend fun <T> select(table: String, query: List<Pair<String, String>>, deserializer: DeserializationStrategy<T>): T {
        val data = send("rest/v1/$table", query, "GET", null, AuthMode.USER)
        return try {
            BrainlixJson.decodeFromString(deserializer, data)
        } catch (e: Exception) {
            throw BackendException.Decoding("$table: ${e.message}")
        }
    }

    // Session

    private enum class AuthMode { ANON_KEY, USER }

    private suspend fun validAccessToken(): String {
        val current = session ?: throw BackendException.NotAuthenticated
        if (current.expiresAt - now() > 60) return current.accessToken
        return refresh(force = false).accessToken
    }

    /// Rafraîchissement unique même si plusieurs appels concurrents en ont besoin.
    private suspend fun refresh(force: Boolean): AuthSession {
        val before = session ?: throw BackendException.NotAuthenticated
        return refreshMutex.withLock {
            val current = session ?: throw BackendException.NotAuthenticated
            // Un autre appel vient de rafraîchir pendant l'attente.
            if (current.accessToken != before.accessToken) return@withLock current
            if (!force && current.expiresAt - now() > 60) return@withLock current
            try {
                adopt(send("auth/v1/token", listOf("grant_type" to "refresh_token"), "POST",
                    jsonOf("refresh_token" to current.refreshToken), AuthMode.ANON_KEY))
            } catch (e: BackendException.Server) {
                if (e.status in 400..401) {
                    clearLocalSession()
                    throw BackendException.NotAuthenticated
                }
                throw e
            }
        }
    }

    @Serializable
    private data class SessionPayload(
        @SerialName("access_token") val accessToken: String,
        @SerialName("refresh_token") val refreshToken: String,
        @SerialName("expires_in") val expiresIn: Double? = null,
        @SerialName("expires_at") val expiresAt: Double? = null,
        val user: User,
    ) {
        @Serializable
        data class User(
            val id: String,
            val email: String? = null,
            @SerialName("is_anonymous") val isAnonymous: Boolean? = null,
        )
    }

    private fun adopt(data: String): AuthSession {
        val payload = try {
            BrainlixJson.decodeFromString(SessionPayload.serializer(), data)
        } catch (e: Exception) {
            throw BackendException.Decoding("session: ${e.message}")
        }
        val expiresAt = payload.expiresAt?.toLong() ?: (now() + (payload.expiresIn ?: 3600.0).toLong())
        val fresh = AuthSession(payload.accessToken, payload.refreshToken, expiresAt, payload.user.id,
            payload.user.isAnonymous ?: false, payload.user.email?.takeIf { it.isNotEmpty() })
        session = fresh
        store.save(fresh)
        return fresh
    }

    // HTTP

    private suspend fun send(
        path: String,
        query: List<Pair<String, String>> = emptyList(),
        method: String,
        body: JsonElement?,
        auth: AuthMode,
    ): String {
        val url = config.url.trimEnd('/').plus("/").plus(path).toHttpUrl().newBuilder()
            .apply { query.forEach { (name, value) -> addQueryParameter(name, value) } }
            .build().toString()
        val token = when (auth) {
            AuthMode.ANON_KEY -> config.anonKey
            AuthMode.USER -> validAccessToken()
        }
        val headers = mapOf(
            "apikey" to config.anonKey,
            "Content-Type" to "application/json",
            "Accept" to "application/json",
            // Cette version sait afficher les nouveaux types de réponses (sinon le serveur sert des questions classiques).
            "x-brainlix-types" to ANSWER_TYPES_VERSION,
            "Authorization" to "Bearer $token",
        )
        val response = try {
            transport.send(HttpRequest(url, method, headers, body?.toString()))
        } catch (e: IOException) {
            throw when (e) {
                is UnknownHostException, is ConnectException, is SocketTimeoutException -> BackendException.Offline
                else -> if (e.message?.contains("timeout", ignoreCase = true) == true) BackendException.Offline
                else BackendException.Server(0, "network", e.message.orEmpty())
            }
        }
        if (response.status !in 200..299) throw parseError(response.status, response.body)
        return response.body
    }
}
