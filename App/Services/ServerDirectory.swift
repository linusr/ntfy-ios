import Foundation
import Observation
import NtfyKit

/// Servers the user has added, with credentials in the shared keychain. The first server is the default.
@Observable
@MainActor
final class ServerDirectory {
    private static let serversKey = "servers"
    private let defaults = SharedContainer.defaults
    private let credentials = CredentialStore()

    private(set) var servers: [URL]

    init() {
        servers = (defaults.stringArray(forKey: Self.serversKey) ?? []).compactMap(URL.init(string:))
    }

    var defaultServer: URL? { servers.first }

    func add(_ url: URL, credential: ServerCredential?) throws {
        try credentials.save(credential, for: url)
        if !servers.contains(url) { servers.append(url) }
        persist()
    }

    func remove(_ url: URL) {
        try? credentials.save(nil, for: url)
        servers.removeAll { $0 == url }
        persist()
    }

    func makeDefault(_ url: URL) {
        guard let index = servers.firstIndex(of: url) else { return }
        servers.insert(servers.remove(at: index), at: 0)
        persist()
    }

    func credential(for url: URL) -> ServerCredential? {
        credentials.credential(for: url)
    }

    func client(for url: URL) -> NtfyClient {
        NtfyClient(baseURL: url, credential: credential(for: url))
    }

    private func persist() {
        defaults.set(servers.map(\.absoluteString), forKey: Self.serversKey)
    }
}
