import UIKit
import UserNotifications
import NtfyKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        model.push.update(token: deviceToken)
        Task { await model.registerForPush() }
    }

    /// Background pushes carry message_delete and message_clear events.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let payload = PushPayload(userInfo: userInfo) else { return .noData }
        let message = payload.message
        let center = UNUserNotificationCenter.current()
        let matching = await center.deliveredNotifications().filter {
            PushPayload(userInfo: $0.request.content.userInfo).map {
                $0.baseURL == payload.baseURL && $0.message.topic == message.topic && $0.message.effectiveSequenceID == message.effectiveSequenceID
            } ?? false
        }
        center.removeDeliveredNotifications(withIdentifiers: matching.map(\.request.identifier))
        if let subscription = model.store.subscription(baseURL: payload.baseURL, topic: message.topic) {
            model.store.apply([message], to: subscription)
            await model.updateBadge()
        }
        return .newData
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await presentationOptions(threadIdentifier: notification.request.content.threadIdentifier)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        guard let payload = PushPayload(userInfo: request.content.userInfo) else { return }
        await handle(payload, actionIdentifier: response.actionIdentifier, requestIdentifier: request.identifier, threadIdentifier: request.content.threadIdentifier)
    }

    private func presentationOptions(threadIdentifier: String) async -> UNNotificationPresentationOptions {
        await model.refreshAll()
        return model.router.selectedTopicKey == threadIdentifier ? [] : [.banner, .list, .sound]
    }

    private func handle(_ payload: PushPayload, actionIdentifier: String, requestIdentifier: String, threadIdentifier: String) async {
        let message = payload.message
        if let action = message.actions?.first(where: { $0.id == actionIdentifier }) {
            await ActionPerformer.perform(action)
            if action.clear == true {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
            }
            return
        }
        guard actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        model.router.selectedTopicKey = threadIdentifier
        if let click = message.click, let url = URL(string: click) {
            await UIApplication.shared.open(url)
        }
    }
}
