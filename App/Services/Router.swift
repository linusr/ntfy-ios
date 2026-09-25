import Foundation
import Observation

/// Navigation state shared with notification handling, so a tapped notification opens its topic.
@Observable
@MainActor
final class Router {
    var selectedTopicKey: String?
    #if DEBUG
    var debugScreen: String?
    #endif

    /// Handles `ntfy-app://topic?key=<topic key>` links from widgets.
    func open(_ url: URL) {
        guard url.scheme == Self.scheme, url.host() == "topic",
              let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "key" })?.value
        else { return }
        selectedTopicKey = key
    }

    static let scheme = "ntfy-app"
}
