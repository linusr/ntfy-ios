import Foundation
import Observation
import WatchConnectivity
import NtfyKit

/// Latest snapshot from the phone, persisted so the list is populated at launch.
@Observable
@MainActor
final class WatchStore: NSObject, WCSessionDelegate {
    nonisolated private static let defaultsKey = "snapshot"

    private(set) var entries: [WatchSnapshot.Entry] = []

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey) {
            apply(data)
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func apply(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        entries = snapshot.entries
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let data = session.receivedApplicationContext[WatchSnapshot.contextKey] as? Data {
            receive(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[WatchSnapshot.contextKey] as? Data {
            receive(data)
        }
    }

    nonisolated private func receive(_ data: Data) {
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        Task { @MainActor in self.apply(data) }
    }
}
