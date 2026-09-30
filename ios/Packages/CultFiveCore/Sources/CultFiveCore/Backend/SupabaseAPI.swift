import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Client Supabase minimal (Auth + RPC PostgREST), sans dépendance.
// Choix documenté dans docs/DECISIONS.md (D-011) : surface d'API réduite et stable, testable sans réseau.

public struct BackendConfig: Sendable {
    public let url: URL
    public let anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}

public struct AuthSession: Codable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let userId: UUID
    public let isAnonymous: Bool
    public let email: String?

    public init(accessToken: String, refreshToken: String, expiresAt: Date, userId: UUID, isAnonymous: Bool, email: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userId = userId
        self.isAnonymous = isAnonymous
        self.email = email
    }
}

public protocol SessionStore: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession?)
}

public final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    private var session: AuthSession?
    private let lock = NSLock()
    public init(_ session: AuthSession? = nil) { self.session = session }
    public func load() -> AuthSession? { lock.lock(); defer { lock.unlock() }; return session }
    public func save(_ session: AuthSession?) { lock.lock(); self.session = session; lock.unlock() }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

public enum BackendError: Error, Equatable, LocalizedError {
    case notAuthenticated
    case offline
    /// `code` : code métier renvoyé par nos RPC (ex. `daily_closed`) ou code d'erreur Auth (ex. `email_exists`).
    case server(status: Int, code: String, message: String)
    case decoding(String)

    public var code: String? {
        if case .server(_, let code, _) = self { return code }
        return nil
    }

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Session expirée. Reconnecte-toi."
        case .offline: return "Pas de connexion. Réessaie dans un instant."
        case .server(_, let code, let message): return BackendError.humanMessage(code: code) ?? message
        case .decoding: return "Réponse inattendue du serveur."
        }
    }

    /// Messages lisibles pour les codes métier connus.
    public static func humanMessage(code: String) -> String? {
        switch code {
        case "handle_taken": return "Ce pseudo est déjà pris."
        case "handle_invalid": return "3 à 20 caractères : lettres, chiffres ou _."
        case "handle_change_too_soon": return "Tu pourras rechanger de pseudo dans quelques jours."
        case "user_not_found": return "Aucun joueur avec ce pseudo."
        case "rate_limited": return "Doucement ! Réessaie un peu plus tard."
        case "insufficient_seeds": return "Pas assez de graines."
        case "help_unavailable": return "Aide indisponible pour cette question."
        case "tree_complete": return "L'arbre de Léon est complet."
        case "chest_not_found": return "Coffre introuvable."
        case "item_not_owned": return "Tu n'as pas encore cet objet."
        case "league_not_found": return "Ligue introuvable."
        case "league_full": return "Cette ligue est complète."
        case "too_many_leagues": return "Tu fais déjà partie de 10 ligues."
        case "referral_code_invalid": return "Code d'invitation inconnu."
        case "referral_already_claimed": return "Invitation déjà utilisée."
        case "referral_requires_account": return "Crée ton compte pour profiter de l'invitation."
        case "email_exists", "email_address_exists": return "Cet e-mail a déjà un compte. Connecte-toi."
        case "otp_expired", "invalid_otp": return "Code invalide ou expiré."
        default: return nil
        }
    }
}

public actor SupabaseAPI {
    public let config: BackendConfig
    private let store: SessionStore
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date
    private var refreshTask: Task<AuthSession, Error>?
    public private(set) var session: AuthSession?

    private let encoder = JSONEncoder()
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = ISO8601.parse(text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date invalide : \(text)")
        }
        return decoder
    }()

    public init(config: BackendConfig, store: SessionStore, transport: HTTPTransport = URLSessionTransport(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.store = store
        self.transport = transport
        self.now = now
        self.session = store.load()
    }

    public var userId: UUID? { session?.userId }
    public var isAnonymous: Bool { session?.isAnonymous ?? true }

    // MARK: Auth

    /// Découverte sans inscription : compte anonyme Supabase, lié plus tard à Apple ou à un e-mail.
    @discardableResult
    public func signInAnonymously() async throws -> AuthSession {
        let data = try await send(path: "auth/v1/signup", method: "POST", body: ["data": .object([:])], auth: .anonKey)
        return try adopt(sessionData: data)
    }

    /// Sign in with Apple. Si la session courante est anonyme, l'identité Apple lui est liée (aucune perte de progression).
    /// Si ce compte Apple existe déjà, on se connecte simplement dessus.
    @discardableResult
    public func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        var body: [String: JSONValue] = ["provider": .string("apple"), "id_token": .string(idToken), "nonce": .string(nonce)]
        if session?.isAnonymous == true {
            body["link_identity"] = .bool(true)
            do {
                let data = try await send(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                          method: "POST", body: body, auth: .user)
                return try adopt(sessionData: data)
            } catch let error as BackendError where error.code == "identity_already_exists" || error.code == "identity_already_linked" {
                body["link_identity"] = nil
            }
        }
        let data = try await send(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                  method: "POST", body: body, auth: .anonKey)
        return try adopt(sessionData: data)
    }

    /// Envoie un code à 6 chiffres par e-mail. Session anonyme : conversion du compte courant (changement d'e-mail).
    public func sendEmailCode(email: String, convertAnonymous: Bool) async throws {
        if convertAnonymous, session?.isAnonymous == true {
            _ = try await send(path: "auth/v1/user", method: "PUT", body: ["email": .string(email)], auth: .user)
        } else {
            _ = try await send(path: "auth/v1/otp", method: "POST",
                               body: ["email": .string(email), "create_user": .bool(true)], auth: .anonKey)
        }
    }

    @discardableResult
    public func verifyEmailCode(email: String, code: String, isConversion: Bool) async throws -> AuthSession {
        let body: [String: JSONValue] = ["type": .string(isConversion ? "email_change" : "email"),
                                         "email": .string(email), "token": .string(code)]
        let data = try await send(path: "auth/v1/verify", method: "POST", body: body,
                                  auth: isConversion ? .user : .anonKey)
        if let fresh = try? adopt(sessionData: data) { return fresh }
        // Conversion : la réponse peut ne contenir que l'utilisateur ; on rafraîchit pour obtenir un jeton à jour.
        return try await refresh(force: true)
    }

    public func signOut() async {
        if session != nil {
            _ = try? await send(path: "auth/v1/logout", method: "POST", body: nil, auth: .user)
        }
        session = nil
        store.save(nil)
    }

    /// Oublie la session locale sans appel réseau (compte supprimé côté serveur).
    public func clearLocalSession() {
        session = nil
        store.save(nil)
    }

    // MARK: RPC

    public func rpc<T: Decodable>(_ function: String, _ params: [String: JSONValue] = [:], as type: T.Type = T.self) async throws -> T {
        let data = try await send(path: "rest/v1/rpc/\(function)", method: "POST", body: params, auth: .user)
        do {
            return try SupabaseAPI.decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.decoding("\(function): \(error)")
        }
    }

    public func rpcVoid(_ function: String, _ params: [String: JSONValue] = [:]) async throws {
        _ = try await send(path: "rest/v1/rpc/\(function)", method: "POST", body: params, auth: .user)
    }

    /// Lecture de tables de référentiel (RLS : lecture publique).
    public func select<T: Decodable>(_ table: String, query: [URLQueryItem], as type: T.Type = T.self) async throws -> T {
        let data = try await send(path: "rest/v1/\(table)", query: query, method: "GET", body: nil, auth: .user)
        do {
            return try SupabaseAPI.decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.decoding("\(table): \(error)")
        }
    }

    // MARK: Session

    private enum AuthMode { case anonKey, user }

    private func validAccessToken() async throws -> String {
        guard let current = session else { throw BackendError.notAuthenticated }
        if current.expiresAt.timeIntervalSince(now()) > 60 { return current.accessToken }
        return try await refresh(force: false).accessToken
    }

    /// Rafraîchissement unique même si plusieurs appels concurrents en ont besoin.
    @discardableResult
    private func refresh(force: Bool) async throws -> AuthSession {
        if let task = refreshTask { return try await task.value }
        guard let current = session else { throw BackendError.notAuthenticated }
        if !force, current.expiresAt.timeIntervalSince(now()) > 60 { return current }
        let task = Task { () throws -> AuthSession in
            let data = try await self.send(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                           method: "POST", body: ["refresh_token": .string(current.refreshToken)], auth: .anonKey)
            return try await self.adopt(sessionData: data)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch let error as BackendError {
            if case .server(let status, _, _) = error, (400...401).contains(status) {
                session = nil
                store.save(nil)
                throw BackendError.notAuthenticated
            }
            throw error
        }
    }

    private struct SessionPayload: Decodable {
        struct User: Decodable {
            let id: UUID
            let email: String?
            let isAnonymous: Bool?
            enum CodingKeys: String, CodingKey {
                case id, email
                case isAnonymous = "is_anonymous"
            }
        }
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double?
        let expiresAt: Double?
        let user: User

        enum CodingKeys: String, CodingKey {
            case user
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case expiresAt = "expires_at"
        }
    }

    @discardableResult
    private func adopt(sessionData data: Data) throws -> AuthSession {
        let payload: SessionPayload
        do {
            payload = try JSONDecoder().decode(SessionPayload.self, from: data)
        } catch {
            throw BackendError.decoding("session: \(error)")
        }
        let expiresAt = payload.expiresAt.map { Date(timeIntervalSince1970: $0) }
            ?? now().addingTimeInterval(payload.expiresIn ?? 3600)
        let fresh = AuthSession(accessToken: payload.accessToken, refreshToken: payload.refreshToken, expiresAt: expiresAt,
                                userId: payload.user.id, isAnonymous: payload.user.isAnonymous ?? false,
                                email: payload.user.email.flatMap { $0.isEmpty ? nil : $0 })
        session = fresh
        store.save(fresh)
        return fresh
    }

    // MARK: HTTP

    private func send(path: String, query: [URLQueryItem] = [], method: String, body: [String: JSONValue]?,
                      auth: AuthMode) async throws -> Data {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw BackendError.decoding("URL invalide") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch auth {
        case .anonKey:
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        case .user:
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .dataNotAllowed:
                throw BackendError.offline
            default:
                throw BackendError.server(status: 0, code: "network", message: error.localizedDescription)
            }
        }
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseAPI.parseError(status: response.statusCode, data: data)
        }
        return data
    }

    static func parseError(status: Int, data: Data) -> BackendError {
        let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        // PostgREST : {"code":"P0001","message":"daily_closed"} — nos RPC lèvent des codes métier dans `message`.
        // Auth : {"error_code":"email_exists","msg":"…"} ou {"error":"invalid_grant","error_description":"…"}.
        let message = json?["message"]?.stringValue ?? json?["msg"]?.stringValue
            ?? json?["error_description"]?.stringValue ?? String(data: data, encoding: .utf8) ?? ""
        let pgCode = json?["code"]?.stringValue
        let code: String
        if let errorCode = json?["error_code"]?.stringValue {
            code = errorCode
        } else if pgCode == "P0001" || pgCode == "28000" || pgCode == "42501" {
            code = message.components(separatedBy: CharacterSet(charactersIn: ": ")).first ?? message
        } else if let error = json?["error"]?.stringValue {
            code = error
        } else {
            code = pgCode ?? "http_\(status)"
        }
        if code == "not_authenticated" { return .notAuthenticated }
        return .server(status: status, code: code, message: message)
    }
}

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ text: String) -> Date? {
        withFraction.date(from: text) ?? plain.date(from: text)
    }
}
