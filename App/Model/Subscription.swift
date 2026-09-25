import Foundation
import SwiftData
import NtfyKit

@Model
final class Subscription {
    #Unique<Subscription>([\.baseURL, \.topic])

    var baseURL: String
    var topic: String
    var displayName: String?
    var symbol: String
    var tint: TopicTint
    var isMuted: Bool
    var lastMessageID: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.subscription)
    var messages: [StoredMessage] = []

    init(baseURL: URL, topic: String, displayName: String? = nil, symbol: String = "bell.fill", tint: TopicTint = .blue) {
        self.baseURL = baseURL.absoluteString
        self.topic = topic
        self.displayName = displayName
        self.symbol = symbol
        self.tint = tint
        self.isMuted = false
        self.createdAt = .now
    }

    var serverURL: URL { URL(string: baseURL)! }
    var title: String { displayName.flatMap { $0.isEmpty ? nil : $0 } ?? topic }
    var key: String { topicKey(baseURL: serverURL, topic: topic) }
    var latestMessage: StoredMessage? { messages.max { $0.time < $1.time } }
    var unreadCount: Int { messages.count { !$0.isRead } }
}

enum TopicTint: String, Codable, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, gray
    var id: Self { self }
}

extension Subscription {
    static let symbolChoices = [
        "bell.fill", "server.rack", "externaldrive.fill", "house.fill", "cart.fill", "shippingbox.fill",
        "chart.line.uptrend.xyaxis", "exclamationmark.triangle.fill", "checkmark.seal.fill", "bolt.fill",
        "thermometer.medium", "lock.fill", "camera.fill", "leaf.fill", "car.fill", "terminal.fill",
    ]
}
