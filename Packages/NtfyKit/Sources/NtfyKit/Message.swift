import Foundation

/// A message in the format of the ntfy JSON stream (`GET /<topic>/json`).
public struct Message: Codable, Hashable, Sendable, Identifiable {
    public enum Event: String, Sendable {
        case message
        case messageDelete = "message_delete"
        case messageClear = "message_clear"
        case pollRequest = "poll_request"
        case open
        case keepalive
    }

    public var id: String
    public var time: Int64
    public var expires: Int64?
    public var event: String
    public var topic: String
    public var title: String?
    public var message: String?
    public var priority: Int?
    public var tags: [String]?
    public var click: String?
    public var icon: String?
    public var actions: [Action]?
    public var attachment: Attachment?
    public var pollID: String?
    public var contentType: String?
    public var encoding: String?
    public var sequenceID: String?

    enum CodingKeys: String, CodingKey {
        case id, time, expires, event, topic, title, message, priority, tags, click, icon, actions, attachment, encoding
        case pollID = "poll_id"
        case contentType = "content_type"
        case sequenceID = "sequence_id"
    }

    public init(
        id: String, time: Int64, event: String = Event.message.rawValue, topic: String,
        title: String? = nil, message: String? = nil, priority: Int? = nil, tags: [String]? = nil,
        click: String? = nil, actions: [Action]? = nil, attachment: Attachment? = nil,
        pollID: String? = nil, contentType: String? = nil, sequenceID: String? = nil
    ) {
        self.id = id
        self.time = time
        self.event = event
        self.topic = topic
        self.title = title
        self.message = message
        self.priority = priority
        self.tags = tags
        self.click = click
        self.actions = actions
        self.attachment = attachment
        self.pollID = pollID
        self.contentType = contentType
        self.sequenceID = sequenceID
    }

    /// Nil for events this client does not know about.
    public var kind: Event? { Event(rawValue: event) }

    public var date: Date { Date(timeIntervalSince1970: TimeInterval(time)) }

    public var effectivePriority: Priority { Priority(rawValue: priority ?? 0) ?? .default }

    /// Messages published without a sequence ID are their own sequence.
    public var effectiveSequenceID: String { sequenceID ?? id }

    public var isMarkdown: Bool { contentType == "text/markdown" }

    /// Tags that map to an emoji, rendered in front of the title.
    public var emojiTags: [String] { (tags ?? []).compactMap(Emoji.lookup) }

    /// Tags without an emoji mapping, rendered as labels.
    public var textTags: [String] { (tags ?? []).filter { Emoji.lookup($0) == nil } }

    /// Parses newline-delimited JSON as returned by the poll API, skipping lines that fail to decode.
    public static func decodeLines(_ data: Data) -> [Message] {
        let decoder = JSONDecoder()
        return data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            try? decoder.decode(Message.self, from: Data(line))
        }
    }
}

public enum Priority: Int, Codable, Sendable, CaseIterable, Comparable {
    case min = 1, low, `default`, high, max

    public static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .min: "Min"
        case .low: "Low"
        case .default: "Default"
        case .high: "High"
        case .max: "Urgent"
        }
    }
}

public struct Action: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case view, http, broadcast, copy
    }

    public var id: String
    public var action: String
    public var label: String
    public var clear: Bool?
    public var url: String?
    public var method: String?
    public var headers: [String: String]?
    public var body: String?
    public var value: String?

    public init(id: String, action: String, label: String, clear: Bool? = nil, url: String? = nil, method: String? = nil, headers: [String: String]? = nil, body: String? = nil, value: String? = nil) {
        self.id = id
        self.action = action
        self.label = label
        self.clear = clear
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.value = value
    }

    public var kind: Kind? { Kind(rawValue: action) }
}

public struct Attachment: Codable, Hashable, Sendable {
    public var name: String
    public var type: String?
    public var size: Int64?
    public var expires: Int64?
    public var url: String

    public init(name: String, type: String? = nil, size: Int64? = nil, expires: Int64? = nil, url: String) {
        self.name = name
        self.type = type
        self.size = size
        self.expires = expires
        self.url = url
    }

    public var isImage: Bool { type?.hasPrefix("image/") ?? false }

    public var isExpired: Bool {
        guard let expires else { return false }
        return Date(timeIntervalSince1970: TimeInterval(expires)) < .now
    }
}
