import Foundation
import Testing
@testable import NtfyKit

@Suite struct MessageTests {
    @Test func decodesFullMessage() throws {
        let json = """
        {"id":"s4PdJozxM8na","time":1727200000,"expires":1727243200,"event":"message","topic":"backups",
         "title":"nas01","message":"Backup **finished**","priority":4,"tags":["white_check_mark","nightly"],
         "click":"https://example.com","content_type":"text/markdown","sequence_id":"job-42",
         "actions":[{"id":"a1","action":"view","label":"Open","url":"https://example.com","clear":true}],
         "attachment":{"name":"log.png","type":"image/png","size":1024,"url":"https://ntfy.example.com/file/x.png"}}
        """
        let m = try JSONDecoder().decode(Message.self, from: Data(json.utf8))
        #expect(m.kind == .message)
        #expect(m.effectivePriority == .high)
        #expect(m.emojiTags == ["✅"])
        #expect(m.textTags == ["nightly"])
        #expect(m.isMarkdown)
        #expect(m.effectiveSequenceID == "job-42")
        #expect(m.actions?.first?.kind == .view)
        #expect(m.attachment?.isImage == true)
    }

    @Test func defaultsWhenFieldsMissing() throws {
        let m = try JSONDecoder().decode(Message.self, from: Data(#"{"id":"a","time":1,"event":"message","topic":"t"}"#.utf8))
        #expect(m.effectivePriority == .default)
        #expect(m.effectiveSequenceID == "a")
        #expect(m.emojiTags.isEmpty)
    }

    @Test func unknownEventDecodes() throws {
        let m = try JSONDecoder().decode(Message.self, from: Data(#"{"id":"a","time":1,"event":"future_event","topic":"t"}"#.utf8))
        #expect(m.kind == nil)
    }

    @Test func decodeLinesSkipsGarbage() {
        let data = Data("""
        {"id":"a","time":1,"event":"message","topic":"t","message":"one"}
        not json
        {"id":"b","time":2,"event":"message","topic":"t","message":"two"}

        """.utf8)
        #expect(Message.decodeLines(data).map(\.id) == ["a", "b"])
    }
}

@Suite struct ServerURLTests {
    @Test(arguments: [
        ("ntfy.example.com", "https://ntfy.example.com"),
        ("https://ntfy.example.com/", "https://ntfy.example.com"),
        ("  http://10.0.0.5:8080//  ", "http://10.0.0.5:8080"),
        ("https://example.com/ntfy/", "https://example.com/ntfy"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(ServerURL.normalize(input)?.absoluteString == expected)
    }

    @Test(arguments: ["", "ftp://example.com", "https://"])
    func rejects(input: String) {
        #expect(ServerURL.normalize(input) == nil)
    }
}
