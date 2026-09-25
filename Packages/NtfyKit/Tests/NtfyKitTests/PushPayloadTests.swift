import Foundation
import Testing
import UserNotifications
@testable import NtfyKit

@Suite struct PushPayloadTests {
    private func userInfo(_ ntfy: [String: Any]) -> [AnyHashable: Any] {
        ["aps": ["alert": ["title": "x"]], "base_url": "https://ntfy.example.com", "ntfy": ntfy]
    }

    @Test func parsesFullPayload() throws {
        let payload = try #require(PushPayload(userInfo: userInfo([
            "id": "abc", "time": 1727200000, "event": "message", "topic": "backups", "message": "hi", "priority": 5,
        ])))
        #expect(payload.baseURL.absoluteString == "https://ntfy.example.com")
        #expect(payload.message.message == "hi")
        #expect(!payload.needsFetch)
    }

    @Test func parsesPollRequest() throws {
        let payload = try #require(PushPayload(userInfo: userInfo([
            "id": "abc", "time": 1727200000, "event": "poll_request", "topic": "backups", "poll_id": "abc",
        ])))
        #expect(payload.needsFetch)
        #expect(payload.messageID == "abc")
    }

    @Test func rejectsForeignPayload() {
        #expect(PushPayload(userInfo: ["aps": ["alert": "hello"]]) == nil)
    }

    @Test func userInfoRoundTrips() throws {
        let original = PushPayload(baseURL: URL(string: "https://ntfy.example.com")!, message: Message(id: "a", time: 1, topic: "t", message: "m"))
        let parsed = try #require(PushPayload(userInfo: original.userInfo))
        #expect(parsed.message == original.message)
        #expect(parsed.baseURL == original.baseURL)
    }
}

@Suite struct NotificationFormatterTests {
    let baseURL = URL(string: "https://ntfy.example.com")!

    @Test func titleCarriesEmojiAndTopicBecomesSubtitle() {
        let content = UNMutableNotificationContent()
        NotificationFormatter.apply(Message(id: "a", time: 1, topic: "backups", title: "nas01", message: "done", priority: 4, tags: ["tada", "prod"]), baseURL: baseURL, to: content)
        #expect(content.title == "🎉 nas01")
        #expect(content.subtitle == "backups")
        #expect(content.body == "done")
        #expect(content.interruptionLevel == .timeSensitive)
        #expect(content.threadIdentifier == "https://ntfy.example.com/backups")
        #expect(PushPayload(userInfo: content.userInfo)?.message.id == "a")
    }

    @Test func topicIsTitleWhenUntitledAndLowPriorityIsSilent() {
        let content = UNMutableNotificationContent()
        NotificationFormatter.apply(Message(id: "a", time: 1, topic: "backups", message: "quiet", priority: 2), baseURL: baseURL, to: content)
        #expect(content.title == "backups")
        #expect(content.subtitle.isEmpty)
        #expect(content.sound == nil)
        #expect(content.interruptionLevel == .passive)
    }

    @Test func markdownIsFlattened() {
        let body = NotificationFormatter.bodyText(Message(id: "a", time: 1, topic: "t", message: "Deploy **done** in `prod`", contentType: "text/markdown"))
        #expect(body == "Deploy done in prod")
    }

    @Test func attachmentOnlyMessage() {
        let body = NotificationFormatter.bodyText(Message(id: "a", time: 1, topic: "t", message: "", attachment: Attachment(name: "report.pdf", url: "https://x")))
        #expect(body == "📎 report.pdf")
    }
}

@Suite struct InboxTests {
    @Test func depositAndDrainInOrder() throws {
        let inbox = Inbox(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let url = URL(string: "https://ntfy.example.com")!
        try inbox.deposit(Message(id: "second", time: 2, topic: "t"), baseURL: url)
        try inbox.deposit(Message(id: "first", time: 1, topic: "t"), baseURL: url)
        #expect(inbox.drain().map(\.message.id) == ["first", "second"])
        #expect(inbox.drain().isEmpty)
    }
}
