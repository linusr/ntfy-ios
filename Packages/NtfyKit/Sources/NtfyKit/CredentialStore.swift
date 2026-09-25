import Foundation
import Security

/// Server credentials in the keychain, shared with the notification service extension via the app group.
public struct CredentialStore: Sendable {
    private let service = "ntfy.server-credential"
    private let accessGroup: String?

    public init(accessGroup: String? = SharedContainer.appGroup) {
        self.accessGroup = accessGroup
    }

    public func credential(for baseURL: URL) -> ServerCredential? {
        var query = baseQuery(baseURL)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(ServerCredential.self, from: data)
    }

    public func save(_ credential: ServerCredential?, for baseURL: URL) throws {
        SecItemDelete(baseQuery(baseURL) as CFDictionary)
        guard let credential else { return }
        var item = baseQuery(baseURL)
        item[kSecValueData as String] = try JSONEncoder().encode(credential)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private func baseQuery(_ baseURL: URL) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: baseURL.absoluteString,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
}
