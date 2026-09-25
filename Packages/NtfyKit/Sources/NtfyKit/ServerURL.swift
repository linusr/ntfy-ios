import Foundation

public enum ServerURL {
    /// Accepts "ntfy.example.com", "https://ntfy.example.com/" and similar; rejects anything without a host.
    public static func normalize(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        while text.hasSuffix("/"), !text.hasSuffix("://") { text.removeLast() }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", let host = url.host(), !host.isEmpty
        else { return nil }
        return url
    }

    /// "ntfy.example.com" for display, keeping any non-root path.
    public static func shortDisplay(_ url: URL) -> String {
        let host = url.host() ?? url.absoluteString
        let path = url.path()
        return path.isEmpty || path == "/" ? host : host + path
    }
}
