import BackgroundTasks
import Foundation
import OSLog

/// Periodic background polling. iOS decides when it runs, typically every 15 minutes to a few
/// hours depending on how often the app is used, so it complements rather than replaces APNs.
@MainActor
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "ntfy") + ".refresh" }

    /// Must be called before the app finishes launching.
    static func register(model: AppModel) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            schedule()
            let work = Task { @MainActor in
                let delivered = await model.backgroundRefresh()
                task.setTaskCompleted(success: delivered || !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Scheduled at launch and on entering the background. The Simulator rejects every request as unavailable.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger(subsystem: identifier, category: "BackgroundRefresh").error("Unable to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }
}
