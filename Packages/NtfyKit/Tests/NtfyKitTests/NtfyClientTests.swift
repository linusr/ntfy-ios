import Foundation
import Testing
@testable import NtfyKit

/// Serves canned responses and records requests. Tests using it run serially.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var recorded = request
        if let stream = request.httpBodyStream {
            stream.open()
            var body = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate(); stream.close() }
            while stream.hasBytesAvailable {
                let n = stream.read(buffer, maxLength: 4096)
                if n <= 0 { break }
                body.append(buffer, count: n)
            }
            recorded.httpBody = body
        }
        Self.requests.append(recorded)
        let (status, data) = Self.handler?(request) ?? (200, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized) struct NtfyClientTests {
    let client: NtfyClient

    init() {
        StubProtocol.requests = []
        StubProtocol.handler = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        client = NtfyClient(baseURL: URL(string: "https://ntfy.example.com")!, credential: .basic(username: "ben", password: "pw"), session: URLSession(configuration: config))
    }

    @Test func pollKeepsOnlyMessages() async throws {
        StubProtocol.handler = { _ in (200, Data("""
        {"id":"o","time":1,"event":"open","topic":"t"}
        {"id":"a","time":2,"event":"message","topic":"t","message":"hi"}
        """.utf8)) }
        let messages = try await client.poll(topic: "t", since: "xyz")
        #expect(messages.map(\.id) == ["a"])
        let url = try #require(StubProtocol.requests.first?.url)
        #expect(url.path() == "/t/json")
        #expect(url.query()?.contains("since=xyz") == true)
        #expect(StubProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == "Basic YmVuOnB3")
    }

    @Test func registerDeviceSendsJSON() async throws {
        try await client.registerDevice(token: "abcd", environment: .sandbox, topics: ["a", "b"])
        let request = try #require(StubProtocol.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/v1/apns")
        let body = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any]
        #expect(body?["token"] as? String == "abcd")
        #expect(body?["environment"] as? String == "sandbox")
        #expect(body?["topics"] as? [String] == ["a", "b"])
    }

    @Test func serverErrorIsSurfaced() async {
        StubProtocol.handler = { _ in (403, Data(#"{"code":40301,"http":403,"error":"forbidden"}"#.utf8)) }
        await #expect(throws: NtfyError.http(status: 403, message: "forbidden")) {
            try await client.poll(topic: "t")
        }
    }

    @Test func publishSetsHeaders() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"id":"n","time":3,"event":"message","topic":"t","message":"hello"}"#.utf8)) }
        let message = try await client.publish(topic: "t", message: "hello", title: "Hi", priority: .high, tags: ["tada"])
        #expect(message.id == "n")
        let request = try #require(StubProtocol.requests.first)
        #expect(request.value(forHTTPHeaderField: "X-Priority") == "4")
        #expect(request.value(forHTTPHeaderField: "X-Tags") == "tada")
        #expect(String(data: try #require(request.httpBody), encoding: .utf8) == "hello")
    }
}
