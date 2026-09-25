import Foundation

/// Recent messages across topics, written by the app for its widgets and the watch.
public struct RecentSnapshot: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        public let topicKey: String
        public let topicTitle: String
        public let symbol: String
        public let tint: String
        public let message: Message

        public init(topicKey: String, topicTitle: String, symbol: String, tint: String, message: Message) {
            self.topicKey = topicKey
            self.topicTitle = topicTitle
            self.symbol = symbol
            self.tint = tint
            self.message = message
        }

        public var id: String { topicKey + "#" + message.id }
    }

    public static let entryLimit = 50

    public let entries: [Entry]
    public let unreadCount: Int
    public let updated: Date

    public init(entries: [Entry], unreadCount: Int, updated: Date = .now) {
        self.entries = Array(entries.sorted { $0.message.time > $1.message.time }.prefix(Self.entryLimit))
        self.unreadCount = unreadCount
        self.updated = updated
    }

    public static let empty = RecentSnapshot(entries: [], unreadCount: 0, updated: .distantPast)

    public static var sharedFile: URL { SharedContainer.url.appending(path: "recent.json") }

    public static func load(from url: URL = sharedFile) -> RecentSnapshot {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(RecentSnapshot.self, from: $0) } ?? .empty
    }

    public func save(to url: URL = sharedFile) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// What the watch needs to fetch messages on its own: servers with credentials, and the subscribed topics.
public struct WatchConfiguration: Codable, Sendable, Equatable {
    public struct Server: Codable, Sendable, Equatable {
        public let url: URL
        public let credential: ServerCredential?

        public init(url: URL, credential: ServerCredential?) {
            self.url = url
            self.credential = credential
        }
    }

    public struct Topic: Codable, Sendable, Equatable {
        public let baseURL: URL
        public let topic: String
        public let title: String
        public let symbol: String
        public let tint: String

        public init(baseURL: URL, topic: String, title: String, symbol: String, tint: String) {
            self.baseURL = baseURL
            self.topic = topic
            self.title = title
            self.symbol = symbol
            self.tint = tint
        }

        public var key: String { topicKey(baseURL: baseURL, topic: topic) }
    }

    public static let contextKey = "configuration"
    /// Application context key for the RecentSnapshot the phone sends along with the configuration.
    public static let snapshotKey = "snapshot"

    public let servers: [Server]
    public let topics: [Topic]

    public init(servers: [Server], topics: [Topic]) {
        self.servers = servers
        self.topics = topics
    }

    public func credential(for url: URL) -> ServerCredential? {
        servers.first { $0.url == url }?.credential
    }
}
