import Foundation
import SwiftData
import NtfyKit

/// A received message. Messages sharing a sequence ID are stored once, holding the latest version.
@Model
final class StoredMessage {
    #Unique<StoredMessage>([\.key])
    #Index<StoredMessage>([\.time])

    /// Server URL, topic and sequence ID; unique across servers.
    var key: String
    var messageID: String
    var time: Date
    var isRead: Bool
    var payload: Data
    var subscription: Subscription?

    init(message: Message, subscription: Subscription) {
        self.key = Self.key(subscription: subscription, sequenceID: message.effectiveSequenceID)
        self.messageID = message.id
        self.time = message.date
        self.isRead = false
        self.payload = (try? JSONEncoder().encode(message)) ?? Data()
        self.subscription = subscription
    }

    static func key(subscription: Subscription, sequenceID: String) -> String {
        subscription.key + "#" + sequenceID
    }

    var message: Message? {
        try? JSONDecoder().decode(Message.self, from: payload)
    }

    func update(with message: Message) {
        messageID = message.id
        time = message.date
        isRead = false
        payload = (try? JSONEncoder().encode(message)) ?? payload
    }
}
