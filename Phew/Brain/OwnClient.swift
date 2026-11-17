import CryptoKit
import Foundation
import Network

/// Door 2 (NB.2): Phew's own client for one server on the fixed list, by hand on URLSession, not with the official
/// Swift kit (the kit pulls in seven packages with swift-nio, and retries and steps up sign-ins by itself; Phew never
/// retries blindly). Streamable HTTP, protocol 2025-11-25: `initialize`, `tools/list`, `tools/call`; an answer comes as
/// JSON or as an event stream. Sign-in: OAuth 2.1 with the server's metadata, open registration as a public client
/// (no secret), PKCE S256, a loopback address on 127.0.0.1. The token lives in the Keychain only, one entry per server,
/// never in a file, a log or the settings. Logs nothing of what it sends or gets.
final class OwnClient: ConnectorTransport, ConnectorSignIn, @unchecked Sendable {  // state under `lock`
    static let version = "2025-11-25"
    /// The longest the browser sign-in may take before the loopback listener closes.
    static let signInWait: TimeInterval = 300
    /// The most one answer may hold, in bytes.
    static let most = 4_000_000
    static let requestTimeout: TimeInterval = 60

    let server: ConnectorServer
    /// Tests shorten it.
    var signInSeconds = OwnClient.signInWait
    private let store: KeyStore
    private let session: URLSession
    private let lock = NSLock()
    private var mcpSession: String?
    private var ready = false
    private var counter = 0

    /// Tests pass a made-up Keychain service and a session whose server is made up.
    init(server: ConnectorServer, service: String = KeyStore().service, session: URLSession = .shared) {
        self.server = server
        store = KeyStore(service: service, account: "connector-\(server.id)")
        self.session = session
    }

    struct Token: Codable, Equatable {
        var access: String
        var refresh: String?
        var expires: Date?
        var client: String
        var tokenURL: URL
    }

    private func saved() -> Token? { store.read().flatMap { try? JSONDecoder().decode(Token.self, from: Data($0.utf8)) } }
    private func save(_ token: Token) throws { try store.save(String(decoding: try JSONEncoder().encode(token), as: UTF8.self)) }

    func signOut() {
        try? store.delete()
        lock.withLock { (mcpSession, ready) = (nil, false) }
    }

    // MARK: Sign-in

    struct Metadata { var issuer: String?; var authorize: URL; var token: URL; var register: URL }

    /// The sign-in service's metadata, at the server's own address. Every address must be https.
    // shortcut: the metadata is read at the server's origin, as Notion serves it (18.4 T2); a server that names another
    // sign-in service through RFC 9728's protected-resource document is not followed. Add it with the next server.
    func metadata() async throws -> Metadata {
        var parts = URLComponents(url: server.url, resolvingAgainstBaseURL: false)!
        parts.path = "/.well-known/oauth-authorization-server"
        parts.query = nil
        let json = try await object(URLRequest(url: parts.url!))
        func address(_ key: String) throws -> URL {
            guard let text = json[key] as? String, let url = URL(string: text), url.scheme == "https" else { throw ConnectorError.signIn }
            return url
        }
        if let methods = json["code_challenge_methods_supported"] as? [String], !methods.contains("S256") { throw ConnectorError.signIn }
        return Metadata(issuer: json["issuer"] as? String, authorize: try address("authorization_endpoint"),
                        token: try address("token_endpoint"), register: try address("registration_endpoint"))
    }

    /// The browser sign-in: a loopback listener on 127.0.0.1, an open registration, the page opened through `open`
    /// (only on the user's Connect), one answer checked against `state`, then the token into the Keychain.
    func signIn(open: @escaping @Sendable (URL) -> Void) async throws {
        let meta = try await metadata()
        let verifier = Self.random(), state = Self.random()
        let loopback = try await Loopback.start(state: state)
        defer { loopback.close() }
        let redirect = "http://127.0.0.1:\(loopback.port)/callback"
        var registration = URLRequest(url: meta.register)
        registration.httpMethod = "POST"
        registration.setValue("application/json", forHTTPHeaderField: "Content-Type")
        registration.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_name": "Phew", "redirect_uris": [redirect], "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"], "token_endpoint_auth_method": "none", "application_type": "native"])
        guard let client = try await object(registration)["client_id"] as? String else { throw ConnectorError.signIn }
        var page = URLComponents(url: meta.authorize, resolvingAgainstBaseURL: false)!
        page.queryItems = (page.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "client_id", value: client),
            URLQueryItem(name: "redirect_uri", value: redirect), URLQueryItem(name: "code_challenge", value: Self.challenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "resource", value: server.url.absoluteString)]
        open(page.url!)
        let answer = try await loopback.answer(within: signInSeconds)
        guard answer["state"] == state, let code = answer["code"] else { throw ConnectorError.signIn }
        // RFC 9207: when the answer names its issuer, it is the one the metadata named.
        if let issuer = answer["iss"], issuer != meta.issuer { throw ConnectorError.signIn }
        let token = try await exchange(meta.token, client: client, [
            "grant_type": "authorization_code", "code": code, "redirect_uri": redirect, "client_id": client,
            "code_verifier": verifier, "resource": server.url.absoluteString], keeping: nil)
        try save(token)
        lock.withLock { (mcpSession, ready) = (nil, false) }
    }

    /// The token endpoint, form-encoded. A refresh with no new refresh token keeps the old one.
    private func exchange(_ url: URL, client: String, _ form: [String: String], keeping refresh: String?) async throws -> Token {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form(form)
        let json = try await object(request)
        guard let access = json["access_token"] as? String, !access.isEmpty else { throw ConnectorError.signIn }
        let seconds = (json["expires_in"] as? NSNumber)?.doubleValue
        return Token(access: access, refresh: json["refresh_token"] as? String ?? refresh,
                     expires: seconds.map { Date().addingTimeInterval($0) }, client: client, tokenURL: url)
    }

    /// The token, refreshed once when it ends within a minute. None, or a refresh refused: sign in again.
    private func token() async throws -> String {
        guard let token = saved() else { throw ConnectorError.notConnected }
        guard let expires = token.expires, expires < Date().addingTimeInterval(60) else { return token.access }
        guard let refresh = token.refresh else { throw ConnectorError.signIn }
        let fresh = try await exchange(token.tokenURL, client: token.client, [
            "grant_type": "refresh_token", "refresh_token": refresh, "client_id": token.client,
            "resource": server.url.absoluteString], keeping: refresh)
        try save(fresh)
        return fresh.access
    }

    /// Form fields, every sign but the unreserved ones percent-encoded.
    static func form(_ fields: [String: String]) -> Data {
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return Data(fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: plain) ?? "")" }.joined(separator: "&").utf8)
    }

    static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: The protocol

    func tools() async throws -> [ConnectorTool] {
        try await start()
        var tools: [ConnectorTool] = [], cursor: String?
        for _ in 0..<20 {  // pages of the list, a ceiling against a server that never ends it
            let result = try await rpc("tools/list", cursor.map { ["cursor": $0] } ?? [:])
            tools += (result["tools"] as? [[String: Any]] ?? []).compactMap(ConnectorTool.init(listed:))
            cursor = result["nextCursor"] as? String
            if cursor == nil { break }
        }
        return tools
    }

    /// One call, only of the tool the permit names. The text parts of the answer, joined; anything else is named only.
    func call(_ permit: ConnectorPermit, arguments: Data) async throws -> ConnectorAnswer {
        try await start()
        let input = (try? JSONSerialization.jsonObject(with: arguments)) as? [String: Any] ?? [:]
        let result = try await rpc("tools/call", ["name": permit.tool, "arguments": input])
        let parts = (result["content"] as? [[String: Any]] ?? []).map { part in
            part["type"] as? String == "text" ? part["text"] as? String ?? "" : "[\(part["type"] as? String ?? "part") left out]"
        }
        return ConnectorAnswer(text: parts.joined(separator: "\n"), isError: result["isError"] as? Bool ?? false)
    }

    /// `initialize` and `notifications/initialized`, once per session.
    private func start() async throws {
        guard !lock.withLock({ ready }) else { return }
        _ = try await rpc("initialize", ["protocolVersion": Self.version, "capabilities": [String: Any](),
                                         "clientInfo": ["name": "Phew", "version": "1"]])
        _ = try await rpc("notifications/initialized", nil)
        lock.withLock { ready = true }
    }

    /// One JSON-RPC message to the server. A notification (`params` nil) has no answer. A 401 means sign in again; a
    /// session the server dropped (404) is started afresh on the next request, never retried now.
    private func rpc(_ method: String, _ params: [String: Any]?) async throws -> [String: Any] {
        let id = lock.withLock { counter += 1; return counter }
        var message: [String: Any] = ["jsonrpc": "2.0", "method": method]
        if let params { message["params"] = params; message["id"] = id }
        var request = URLRequest(url: server.url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        if method != "initialize" { request.setValue(Self.version, forHTTPHeaderField: "MCP-Protocol-Version") }
        if let mcpSession = lock.withLock({ mcpSession }) { request.setValue(mcpSession, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try JSONSerialization.data(withJSONObject: message)
        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw ConnectorError.signIn }
        if status == 404 { lock.withLock { (mcpSession, ready) = (nil, false) } }
        guard (200..<300).contains(status) else { throw ConnectorError.failed }
        if let given = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Mcp-Session-Id") { lock.withLock { mcpSession = given } }
        guard params != nil else { return [:] }
        let type = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let answer = type.hasPrefix("text/event-stream") ? try await Self.event(bytes, id: id) : try await Self.json(bytes)
        guard answer["error"] == nil, let result = answer["result"] as? [String: Any] else { throw ConnectorError.failed }
        return result
    }

    /// A JSON answer, at most `most` bytes.
    static func json(_ bytes: URLSession.AsyncBytes) async throws -> [String: Any] {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > most { throw ConnectorError.tooLarge }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// An event stream: the message answering `id`. Other messages (progress, logging) are skipped.
    static func event(_ bytes: URLSession.AsyncBytes, id: Int) async throws -> [String: Any] {
        var read = 0, data = ""
        for try await line in bytes.lines {
            read += line.utf8.count
            if read > most { throw ConnectorError.tooLarge }
            guard line.hasPrefix("data:") else { continue }
            data += (data.isEmpty ? "" : "\n") + line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            // A message may span several data lines: it is whole once it reads as JSON.
            guard let message = (try? JSONSerialization.jsonObject(with: Data(data.utf8))) as? [String: Any] else { continue }
            data = ""
            if (message["id"] as? NSNumber)?.intValue == id { return message }
        }
        return [:]
    }

    /// A JSON object from an https request. Any other status is a failure, named by no word of the answer.
    private func object(_ request: URLRequest) async throws -> [String: Any] {
        var request = request
        request.timeoutInterval = Self.requestTimeout
        let (bytes, response) = try await session.bytes(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { throw ConnectorError.signIn }
        return try await Self.json(bytes)
    }
}

/// The address the browser comes back to after a sign-in: bound to 127.0.0.1 only, on a free port. It takes the one
/// request to `/callback` that carries the sign-in's own `state`, answers it with one fixed line, and closes; any other
/// request gets "Not found." and it keeps listening; or it closes at the timeout. Reads the query of requests only.
final class Loopback: @unchecked Sendable {  // state under `lock`
    private let listener: NWListener
    private let state: String
    private let queue = DispatchQueue(label: "phew.loopback")
    private let lock = NSLock()
    private var waiting: CheckedContinuation<[String: String], Error>?
    private var got: Result<[String: String], Error>?
    private(set) var port: UInt16 = 0

    private init(_ listener: NWListener, state: String) { (self.listener, self.state) = (listener, state) }

    static func start(state: String) async throws -> Loopback {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        parameters.acceptLocalOnly = true
        let loopback = Loopback(try NWListener(using: parameters), state: state)
        try await withCheckedThrowingContinuation { (started: CheckedContinuation<Void, Error>) in
            let once = OnceFlag()
            loopback.listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    loopback.port = loopback.listener.port?.rawValue ?? 0
                    if once.first() { started.resume() }
                case .failed, .cancelled:
                    if once.first() { started.resume(throwing: ConnectorError.signIn) }
                default: break
                }
            }
            loopback.listener.newConnectionHandler = { loopback.take($0) }
            loopback.listener.start(queue: loopback.queue)
        }
        return loopback
    }

    /// Until the answer: a request to `/callback` with this sign-in's `state` ends it; any other is answered "Not found."
    /// and the listener goes on. After the answer every request is closed unread.
    private func take(_ connection: NWConnection) {
        guard lock.withLock({ got == nil }) else { return connection.cancel() }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else { return connection.cancel() }
            let head = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
            let line = head.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
            let parts = line.split(separator: " ")
            var query: [String: String]?
            if parts.count >= 2, parts[0] == "GET", let target = URLComponents(string: String(parts[1])), target.path == "/callback" {
                let items = Dictionary((target.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
                if items["state"] == state { query = items }
            }
            let page = query == nil ? "Not found." : "Phew got the sign-in. You can close this tab."
            let reply = "HTTP/1.1 \(query == nil ? "404 Not Found" : "200 OK")\r\nContent-Type: text/plain; charset=utf-8\r\n"
                + "Content-Length: \(page.utf8.count)\r\nConnection: close\r\n\r\n\(page)"
            connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
            if let query { finish(.success(query)) }
        }
    }

    private func finish(_ result: Result<[String: String], Error>) {
        let waiting = lock.withLock { () -> CheckedContinuation<[String: String], Error>? in
            guard got == nil else { return nil }
            got = result
            defer { self.waiting = nil }
            return self.waiting
        }
        listener.cancel()
        waiting?.resume(with: result)
    }

    /// The query of the one right request, or `signIn` after `seconds`.
    func answer(within seconds: TimeInterval) async throws -> [String: String] {
        queue.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.finish(.failure(ConnectorError.signIn)) }
        return try await withCheckedThrowingContinuation { continuation in
            let ready = lock.withLock { () -> Result<[String: String], Error>? in
                if got == nil { waiting = continuation }
                return got
            }
            if let ready { continuation.resume(with: ready) }
        }
    }

    func close() { finish(.failure(ConnectorError.signIn)) }
}

/// True the first time only.
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func first() -> Bool { lock.withLock { defer { done = true }; return !done } }
}
