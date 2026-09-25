import Foundation
import WatchConnectivity
import NtfyKit

/// Sends the watch its server configuration and the latest messages. Application context keeps only
/// the latest value, so the watch catches up whenever it next wakes. The newest update is held until
/// the session is activated and the watch app is installed.
final class WatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let lock = NSLock()
    private var pending: [String: Any]?

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(configuration: WatchConfiguration, snapshot: RecentSnapshot) {
        guard let configurationData = try? JSONEncoder().encode(configuration),
              let snapshotData = try? JSONEncoder().encode(snapshot)
        else { return }
        lock.withLock {
            pending = [WatchConfiguration.contextKey: configurationData, WatchConfiguration.snapshotKey: snapshotData]
        }
        flush()
    }

    private func flush() {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let context = lock.withLock {
            defer { pending = nil }
            return pending
        }
        if let context {
            try? session.updateApplicationContext(context)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        flush()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        flush()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
