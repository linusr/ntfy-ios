import Foundation
import Observation
import SwiftData
import UserNotifications
import NtfyKit

/// App-wide state and the operations views and notification handling share.
@Observable
@MainActor
final class AppModel {
    let container: ModelContainer
    let servers = ServerDirectory()
    let push = PushRegistrar()
    let router = Router()
    private let watch = WatchBridge()
    private(set) var isRefreshing = false
    private(set) var lastError: String?

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try! ModelContainer(for: Subscription.self, StoredMessage.self, configurations: configuration)
    }

    var store: MessageStore { MessageStore(context: container.mainContext) }

    func subscribe(server: URL, topic: String, displayName: String?, symbol: String, tint: TopicTint) async {
        let subscription = Subscription(baseURL: server, topic: topic, displayName: displayName, symbol: symbol, tint: tint)
        container.mainContext.insert(subscription)
        try? container.mainContext.save()
        await requestNotificationPermission()
        await registerForPush()
        await refresh(subscription)
    }

    func unsubscribe(_ subscription: Subscription) async {
        container.mainContext.delete(subscription)
        try? container.mainContext.save()
        await registerForPush()
        await updateBadge()
    }

    func removeServer(_ server: URL) async {
        store.subscriptions().filter { $0.serverURL == server }.forEach(container.mainContext.delete)
        try? container.mainContext.save()
        await push.unregister(from: server, directory: servers)
        servers.remove(server)
        await updateBadge()
    }

    /// Imports pushed messages, then fetches anything missed from each server.
    func refreshAll() async {
        #if DEBUG
        await DebugSeed.apply(to: self)
        #endif
        store.ingestInbox()
        isRefreshing = true
        defer { isRefreshing = false }
        lastError = nil
        for subscription in store.subscriptions() {
            await refresh(subscription)
        }
        await updateBadge()
        sendWatchSnapshot()
    }

    func refresh(_ subscription: Subscription) async {
        do {
            let messages = try await servers.client(for: subscription.serverURL).poll(topic: subscription.topic, since: subscription.lastMessageID)
            store.apply(messages, to: subscription)
        } catch {
            lastError = "\(subscription.title): \(error.localizedDescription)"
        }
    }

    func registerForPush() async {
        var topics: [URL: [String]] = Dictionary(uniqueKeysWithValues: servers.servers.map { ($0, []) })
        for subscription in store.subscriptions() where !subscription.isMuted {
            topics[subscription.serverURL, default: []].append(subscription.topic)
        }
        await push.register(topicsByServer: topics, directory: servers)
    }

    func markRead(_ subscription: Subscription) async {
        store.markAllRead(subscription)
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().filter { $0.request.content.threadIdentifier == subscription.key }
        center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier))
        await updateBadge()
    }

    func sendWatchSnapshot() {
        let entries = store.subscriptions()
            .flatMap { subscription in
                subscription.messages.compactMap { stored in
                    stored.message.map { WatchSnapshot.Entry(topicTitle: subscription.title, symbol: subscription.symbol, tint: subscription.tint.rawValue, message: $0) }
                }
            }
            .sorted { $0.message.time > $1.message.time }
            .prefix(WatchSnapshot.entryLimit)
        watch.send(WatchSnapshot(entries: Array(entries)))
    }

    func updateBadge() async {
        let unread = store.subscriptions().reduce(0) { $0 + $1.unreadCount }
        try? await UNUserNotificationCenter.current().setBadgeCount(unread)
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
}
