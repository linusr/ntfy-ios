import Foundation
import WatchConnectivity
import NtfyKit

/// Mirrors recent messages to the watch app. Application context keeps only the latest snapshot,
/// so the watch catches up whenever it next wakes.
final class WatchBridge: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ snapshot: WatchSnapshot) {
        guard let session, session.activationState == .activated, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        try? session.updateApplicationContext([WatchSnapshot.contextKey: data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
