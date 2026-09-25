import Foundation
import NtfyKit

/// Holds one message stream per server while the app is in the foreground, reconnecting with
/// backoff and resuming from the newest stored message so nothing is missed between connections.
@MainActor
final class LiveUpdates {
    private unowned let model: AppModel
    private var tasks: [Task<Void, Never>] = []

    init(model: AppModel) {
        self.model = model
    }

    func restart() {
        stop()
        let topicsByServer = Dictionary(grouping: model.store.subscriptions(), by: \.serverURL)
        for (server, subscriptions) in topicsByServer {
            let topics = subscriptions.map(\.topic)
            tasks.append(Task { await self.run(server: server, topics: topics) })
        }
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func run(server: URL, topics: [String]) async {
        var delay: Duration = .seconds(2)
        while !Task.isCancelled {
            let since = newestMessageID(server: server)
            do {
                for try await message in model.servers.client(for: server).stream(topics: topics, since: since) {
                    delay = .seconds(2)
                    await model.receive(message, from: server)
                }
            } catch is CancellationError {
                return
            } catch {
                // Network errors and server restarts end the stream; reconnect below
            }
            try? await Task.sleep(for: delay)
            delay = min(delay * 2, .seconds(60))
        }
    }

    private func newestMessageID(server: URL) -> String? {
        model.store.subscriptions()
            .filter { $0.serverURL == server }
            .compactMap(\.latestMessage)
            .max { $0.time < $1.time }?
            .messageID
    }
}
