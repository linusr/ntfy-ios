import Foundation

/// The ntfy part of an APNs payload: `base_url` plus the message under the `ntfy` key.
public struct PushPayload: Sendable {
    public let baseURL: URL
    public let message: Message

    public init(baseURL: URL, message: Message) {
        self.baseURL = baseURL
        self.message = message
    }

    public init?(userInfo: [AnyHashable: Any]) {
        guard let base = userInfo["base_url"] as? String, let baseURL = URL(string: base),
              let raw = userInfo["ntfy"], JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let message = try? JSONDecoder().decode(Message.self, from: data)
        else { return nil }
        self.init(baseURL: baseURL, message: message)
    }

    /// True when only the message ID was pushed and the content must be fetched from the server.
    public var needsFetch: Bool { message.kind == .pollRequest }

    /// ID of the message a poll request refers to.
    public var messageID: String { message.pollID ?? message.id }

    public var userInfo: [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["base_url": baseURL.absoluteString]
        if let data = try? JSONEncoder().encode(message), let object = try? JSONSerialization.jsonObject(with: data) {
            info["ntfy"] = object
        }
        return info
    }
}

/// Identifies a topic across servers, e.g. for notification thread IDs.
public func topicKey(baseURL: URL, topic: String) -> String {
    baseURL.absoluteString + "/" + topic
}
