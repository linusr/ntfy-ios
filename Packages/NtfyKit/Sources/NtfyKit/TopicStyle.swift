import SwiftUI

/// Colors for the topic tint names stored with each subscription.
public enum TopicStyle {
    public static func color(_ tint: String) -> Color {
        switch tint {
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "gray": .gray
        default: .blue
        }
    }

    /// Link that opens a topic in the app, used by widgets.
    public static func topicLink(_ key: String) -> URL {
        var components = URLComponents()
        components.scheme = "ntfy-app"
        components.host = "topic"
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        return components.url!
    }
}
