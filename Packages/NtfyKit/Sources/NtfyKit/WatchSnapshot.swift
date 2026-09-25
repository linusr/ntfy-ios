import Foundation

/// Recent messages the phone sends to the watch app through WatchConnectivity.
public struct WatchSnapshot: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        public let topicTitle: String
        public let symbol: String
        public let tint: String
        public let message: Message

        public init(topicTitle: String, symbol: String, tint: String, message: Message) {
            self.topicTitle = topicTitle
            self.symbol = symbol
            self.tint = tint
            self.message = message
        }

        public var id: String { message.id }
    }

    public static let contextKey = "snapshot"
    public static let entryLimit = 50

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }
}
