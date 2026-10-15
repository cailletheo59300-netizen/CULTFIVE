package app.brainlix.core

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import java.io.File
import java.net.UnknownHostException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

/// Transport simulé : enregistre les requêtes, renvoie des réponses programmées. Miroir de `SupabaseAPITests.swift`.
private class MockTransport(private val handler: (HttpRequest) -> Pair<Int, String>) : HttpTransport {
    val requests = mutableListOf<HttpRequest>()
    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        delay(5) // laisse les appels concurrents se croiser
        val (status, body) = handler(request)
        return HttpResponse(status, body)
    }
}

private val HttpRequest.path: String get() = java.net.URI(url).path

class SupabaseApiTest {
    private val config = BackendConfig("https://example.supabase.co", "anon-key")
    private val userId = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
    private val now = System.currentTimeMillis() / 1000

    private fun sessionJson(token: String, expiresIn: Int = 3600, anonymous: Boolean = true) =
        """{"access_token":"$token","refresh_token":"r-$token","expires_in":$expiresIn,"user":{"id":"$userId","is_anonymous":$anonymous}}"""

    private fun stored(token: String, expiresAt: Long) = InMemorySessionStore(AuthSession(token, "ref", expiresAt, userId, false))

    @Test fun anonymousSignInStoresSession(): Unit = runBlocking {
        val store = InMemorySessionStore()
        val transport = MockTransport { 200 to sessionJson("t1") }
        val api = SupabaseApi(config, store, transport)
        val session = api.signInAnonymously()
        assertTrue(session.isAnonymous)
        assertEquals("t1", store.load()?.accessToken)
        assertEquals("/auth/v1/signup", transport.requests.first().path)
        assertEquals("anon-key", transport.requests.first().headers["apikey"])
        assertEquals("2", transport.requests.first().headers["x-brainlix-types"])
    }

    @Test fun rpcUsesBearerAndDecodesBusinessErrors(): Unit = runBlocking {
        val transport = MockTransport { request ->
            if (request.path == "/rest/v1/rpc/daily_question") {
                400 to """{"code":"P0001","details":null,"hint":null,"message":"daily_closed"}"""
            } else {
                200 to """{"date":"2026-09-26","state":"available","answers":[],"streak":3,"streak_freezes":1,"seconds_until_next":600}"""
            }
        }
        val service = LiveGameService(SupabaseApi(config, stored("tok", now + 3600), transport))
        assertEquals(3, service.dailyStatus().streak)
        assertEquals("Bearer tok", transport.requests.last().headers["Authorization"])
        val error = assertFailsWith<BackendException.Server> { service.dailyQuestion("run", 1) }
        assertEquals("daily_closed", error.code)
        val body = BrainlixJson.parseToJsonElement(transport.requests.last().body!!)
        assertEquals(1.0, body["p_position"].doubleValue)
    }

    @Test fun expiredTokenIsRefreshedOnce(): Unit = runBlocking {
        val transport = MockTransport { request ->
            if (request.path == "/auth/v1/token") 200 to sessionJson("new", anonymous = false) else 200 to "[]"
        }
        val service = LiveGameService(SupabaseApi(config, stored("old", now - 10), transport))
        val a = async { service.skills() }
        val b = async { service.skills() }
        a.await(); b.await()
        assertEquals(1, transport.requests.count { it.path == "/auth/v1/token" }, "un seul rafraîchissement pour des appels concurrents")
        assertTrue(transport.requests.filter { it.path.startsWith("/rest") }.all { it.headers["Authorization"] == "Bearer new" })
    }

    @Test fun revokedRefreshTokenSignsOut(): Unit = runBlocking {
        val store = stored("old", now - 10)
        val transport = MockTransport { 400 to """{"error":"invalid_grant","error_description":"Invalid Refresh Token"}""" }
        assertFailsWith<BackendException.NotAuthenticated> { LiveGameService(SupabaseApi(config, store, transport)).skills() }
        assertNull(store.load())
    }

    @Test fun authErrorCodes() {
        val error = SupabaseApi.parseError(422, """{"code":422,"error_code":"email_exists","msg":"Email address already exists"}""")
        assertEquals("email_exists", error.code)
        assertEquals("Cet e-mail a déjà un compte. Connecte-toi.", error.message)
    }

    @Test fun networkFailureIsOfflineAndReported(): Unit = runBlocking {
        val reported = mutableListOf<Pair<String, String>>()
        val api = SupabaseApi(config, stored("tok", now + 3600), { throw UnknownHostException() })
        api.errorHandler = { function, code -> reported += function to code }
        assertFailsWith<BackendException.Offline> { LiveGameService(api).profile() }
        assertEquals(listOf("profile_me" to "offline"), reported)
    }

    @Test fun okHttpTransportSendsHeadersAndBody(): Unit = runBlocking {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("""{"min_build":12}"""))
        server.start()
        try {
            val api = SupabaseApi(BackendConfig(server.url("/").toString(), "anon-key"), stored("tok", now + 3600))
            assertEquals(12, LiveGameService(api).appSettings().minBuild)
            val recorded = server.takeRequest()
            assertEquals("/rest/v1/rpc/app_settings", recorded.path)
            assertEquals("Bearer tok", recorded.getHeader("Authorization"))
            assertEquals("2", recorded.getHeader("x-brainlix-types"))
            assertEquals("{}", recorded.body.readUtf8())
        } finally {
            server.shutdown()
        }
    }

    @Test fun selectBuildsPostgrestQuery(): Unit = runBlocking {
        val transport = MockTransport { 200 to """[{"id":"histoire","name":"Histoire","daily_slot":"histoire","sort":1}]""" }
        val domains = LiveGameService(SupabaseApi(config, stored("tok", now + 3600), transport)).domains()
        assertEquals("Histoire", domains.single().name)
        assertEquals(
            "https://example.supabase.co/rest/v1/domains?select=id%2Cname%2Cdaily_slot%2Csort&is_active=eq.true&order=sort",
            transport.requests.single().url,
        )
    }
}

class OfflineAttemptQueueTest {
    @Test fun persistsDeduplicatesAndDrains(): Unit = runBlocking {
        val file = File.createTempFile("queue", ".json").also { it.delete() }
        val attempt = PlayAttempt("a1", "q1", GivenAnswer.Bool(true), 1200)
        val queue = OfflineAttemptQueue(file)
        queue.enqueue("s1", listOf(attempt))
        queue.enqueue("s1", listOf(attempt))
        assertEquals(1, queue.pendingCount(), "pas de doublon")

        val reloaded = OfflineAttemptQueue(file)
        assertEquals(1, reloaded.pendingCount(), "survit à un redémarrage")

        assertEquals(0, reloaded.drain { _, _ -> throw IllegalStateException("hors ligne") })
        assertEquals(1, reloaded.drain { id, attempts ->
            assertEquals("s1", id)
            assertEquals(1, attempts.size)
            assertEquals(GivenAnswer.Bool(true), attempts.single().given)
        })
        assertEquals(0, reloaded.pendingCount())
        file.delete()
    }
}
