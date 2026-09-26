import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CultFiveCore

/// Transport simulé : enregistre les requêtes, renvoie des réponses programmées.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = (URLRequest) -> (Int, String)
    private let lock = NSLock()
    private var handler: Handler
    private(set) var requests: [URLRequest] = []

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        let (status, body) = handler(request)
        lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

final class SupabaseAPITests: XCTestCase {
    let config = BackendConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key")
    let userId = UUID()

    private func sessionJSON(token: String, expiresIn: Int = 3600, anonymous: Bool = true) -> String {
        #"{"access_token":"\#(token)","refresh_token":"r-\#(token)","expires_in":\#(expiresIn),"user":{"id":"\#(userId.uuidString)","is_anonymous":\#(anonymous)}}"#
    }

    func testAnonymousSignInStoresSession() async throws {
        let store = InMemorySessionStore()
        let transport = MockTransport { _ in (200, self.sessionJSON(token: "t1")) }
        let api = SupabaseAPI(config: config, store: store, transport: transport)
        let session = try await api.signInAnonymously()
        XCTAssertTrue(session.isAnonymous)
        XCTAssertEqual(store.load()?.accessToken, "t1")
        XCTAssertEqual(transport.requests.first?.url?.path, "/auth/v1/signup")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "apikey"), "anon-key")
    }

    func testRPCUsesBearerAndDecodesBusinessErrors() async throws {
        let store = InMemorySessionStore(AuthSession(accessToken: "tok", refreshToken: "ref", expiresAt: Date().addingTimeInterval(3600),
                                                     userId: userId, isAnonymous: false, email: nil))
        let transport = MockTransport { request in
            if request.url?.path == "/rest/v1/rpc/daily_question" {
                return (400, #"{"code":"P0001","details":null,"hint":null,"message":"daily_closed"}"#)
            }
            return (200, #"{"date":"2026-09-26","state":"available","answers":[],"streak":3,"streak_freezes":1,"seconds_until_next":600}"#)
        }
        let api = SupabaseAPI(config: config, store: store, transport: transport)
        let service = LiveGameService(api: api)
        let status = try await service.dailyStatus()
        XCTAssertEqual(status.streak, 3)
        XCTAssertEqual(transport.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        do {
            _ = try await service.dailyQuestion(run: UUID(), position: 1)
            XCTFail("doit échouer")
        } catch let error as BackendError {
            XCTAssertEqual(error.code, "daily_closed")
        }
    }

    func testExpiredTokenIsRefreshedOnce() async throws {
        let store = InMemorySessionStore(AuthSession(accessToken: "old", refreshToken: "ref", expiresAt: Date().addingTimeInterval(-10),
                                                     userId: userId, isAnonymous: false, email: nil))
        let transport = MockTransport { request in
            if request.url?.path == "/auth/v1/token" { return (200, self.sessionJSON(token: "new", anonymous: false)) }
            return (200, "[]")
        }
        let api = SupabaseAPI(config: config, store: store, transport: transport)
        let service = LiveGameService(api: api)
        async let a = service.skills()
        async let b = service.skills()
        _ = try await (a, b)
        let refreshes = transport.requests.filter { $0.url?.path == "/auth/v1/token" }
        XCTAssertEqual(refreshes.count, 1, "un seul rafraîchissement pour des appels concurrents")
        XCTAssertTrue(transport.requests.filter { $0.url?.path.hasPrefix("/rest") == true }
            .allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer new" })
    }

    func testRevokedRefreshTokenSignsOut() async throws {
        let store = InMemorySessionStore(AuthSession(accessToken: "old", refreshToken: "ref", expiresAt: Date().addingTimeInterval(-10),
                                                     userId: userId, isAnonymous: false, email: nil))
        let transport = MockTransport { _ in (400, #"{"error":"invalid_grant","error_description":"Invalid Refresh Token"}"#) }
        let api = SupabaseAPI(config: config, store: store, transport: transport)
        do {
            _ = try await LiveGameService(api: api).skills()
            XCTFail("doit échouer")
        } catch let error as BackendError {
            XCTAssertEqual(error, .notAuthenticated)
        }
        XCTAssertNil(store.load())
    }

    func testAuthErrorCodes() {
        let error = SupabaseAPI.parseError(status: 422, data: Data(#"{"code":422,"error_code":"email_exists","msg":"Email address already exists"}"#.utf8))
        XCTAssertEqual(error.code, "email_exists")
        XCTAssertEqual(error.errorDescription, "Cet e-mail a déjà un compte. Connecte-toi.")
    }
}

final class OfflineAttemptQueueTests: XCTestCase {
    func testPersistsDeduplicatesAndDrains() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-\(UUID().uuidString).json")
        let session = UUID()
        let attempt = PlayAttempt(questionId: UUID(), given: .bool(true), responseMs: 1200)
        let queue = OfflineAttemptQueue(fileURL: url)
        await queue.enqueue(session: session, attempts: [attempt])
        await queue.enqueue(session: session, attempts: [attempt])
        let pending = await queue.pendingCount
        XCTAssertEqual(pending, 1, "pas de doublon")

        let reloaded = OfflineAttemptQueue(fileURL: url)
        let reloadedCount = await reloaded.pendingCount
        XCTAssertEqual(reloadedCount, 1, "survit à un redémarrage")

        struct Offline: Error {}
        var sent = await reloaded.drain { _, _ in throw Offline() }
        XCTAssertEqual(sent, 0)
        sent = await reloaded.drain { id, attempts in
            XCTAssertEqual(id, session)
            XCTAssertEqual(attempts.count, 1)
        }
        XCTAssertEqual(sent, 1)
        let remaining = await reloaded.pendingCount
        XCTAssertEqual(remaining, 0)
    }
}
