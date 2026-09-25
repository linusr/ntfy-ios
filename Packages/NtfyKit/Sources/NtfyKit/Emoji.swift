import Foundation

/// Maps ntfy tags to emoji using GitHub's gemoji aliases, the same set the ntfy web and Android apps use.
public enum Emoji {
    private static let aliases: [String: String] = {
        guard let url = Bundle.module.url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }()

    public static func lookup(_ alias: String) -> String? {
        aliases[alias]
    }
}
