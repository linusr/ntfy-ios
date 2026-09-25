import Foundation

public enum ServerCredential: Codable, Hashable, Sendable {
    case basic(username: String, password: String)
    case token(String)

    public var authorizationHeader: String {
        switch self {
        case let .basic(username, password):
            "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        case let .token(token):
            "Bearer " + token
        }
    }
}

public enum NtfyError: LocalizedError, Equatable {
    case http(status: Int, message: String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .http(status, message?):
            "\(message) (HTTP \(status))"
        case let .http(status, nil):
            HTTPURLResponse.localizedString(forStatusCode: status).capitalized + " (HTTP \(status))"
        case .invalidResponse:
            "The server sent an unexpected response."
        }
    }
}

/// APNs gateway a device token belongs to. Xcode debug builds get sandbox tokens.
public enum PushEnvironment: String, Codable, Sendable {
    case production, sandbox
}

/// Client for one ntfy server.
public struct NtfyClient: Sendable {
    public let baseURL: URL
    public let credential: ServerCredential?
    private let session: URLSession

    public init(baseURL: URL, credential: ServerCredential? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.credential = credential
        self.session = session
    }

    /// Cached messages for a topic, oldest first. `since` is a message ID, or nil for everything the server has cached.
    public func poll(topic: String, since: String? = nil) async throws -> [Message] {
        let data = try await get(topic: topic, query: [
            URLQueryItem(name: "poll", value: "1"),
            URLQueryItem(name: "since", value: since ?? "all"),
        ])
        return Message.decodeLines(data).filter { $0.kind == .message }
    }

    /// A single cached message, used to resolve poll requests.
    public func message(topic: String, id: String) async throws -> Message? {
        let data = try await get(topic: topic, query: [
            URLQueryItem(name: "poll", value: "1"),
            URLQueryItem(name: "id", value: id),
        ])
        return Message.decodeLines(data).first { $0.id == id && $0.kind == .message }
    }

    @discardableResult
    public func publish(topic: String, message: String, title: String? = nil, priority: Priority? = nil, tags: [String] = []) async throws -> Message {
        var request = makeRequest(url: baseURL.appending(path: topic), method: "POST")
        request.httpBody = Data(message.utf8)
        if let title, !title.isEmpty { request.setValue(title, forHTTPHeaderField: "X-Title") }
        if let priority { request.setValue(String(priority.rawValue), forHTTPHeaderField: "X-Priority") }
        if !tags.isEmpty { request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "X-Tags") }
        let data = try await send(request)
        return try JSONDecoder().decode(Message.self, from: data)
    }

    /// Registers the device for APNs delivery of the given topics, replacing any earlier topic list.
    public func registerDevice(token: String, environment: PushEnvironment, topics: [String]) async throws {
        struct Body: Encodable { let token: String; let environment: PushEnvironment; let topics: [String] }
        var request = makeRequest(url: baseURL.appending(path: "v1/apns"), method: "POST")
        request.httpBody = try JSONEncoder().encode(Body(token: token, environment: environment, topics: topics))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await send(request)
    }

    public func unregisterDevice(token: String) async throws {
        struct Body: Encodable { let token: String }
        var request = makeRequest(url: baseURL.appending(path: "v1/apns"), method: "DELETE")
        request.httpBody = try JSONEncoder().encode(Body(token: token))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await send(request)
    }

    /// Checks that the server is reachable and, if a credential is set, that it is accepted.
    public func verify() async throws {
        let path = credential == nil ? "v1/health" : "v1/account"
        try await send(makeRequest(url: baseURL.appending(path: path), method: "GET"))
    }

    /// Performs an ntfy "http" action button.
    public func perform(_ action: Action) async throws {
        guard let urlString = action.url, let url = URL(string: urlString) else { throw NtfyError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = action.method ?? "POST"
        request.httpBody = action.body.map { Data($0.utf8) }
        action.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        try await send(request)
    }

    private func get(topic: String, query: [URLQueryItem]) async throws -> Data {
        let url = baseURL.appending(path: "\(topic)/json").appending(queryItems: query)
        return try await send(makeRequest(url: url, method: "GET"))
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if let credential { request.setValue(credential.authorizationHeader, forHTTPHeaderField: "Authorization") }
        return request
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NtfyError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            struct ServerError: Decodable { let error: String }
            let message = try? JSONDecoder().decode(ServerError.self, from: data).error
            throw NtfyError.http(status: http.statusCode, message: message)
        }
        return data
    }
}
