import Foundation
import Observation

/// Navigation state shared with notification handling, so a tapped notification opens its topic.
@Observable
@MainActor
final class Router {
    var selectedTopicKey: String?
}
