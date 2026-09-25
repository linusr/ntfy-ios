import SwiftUI

@main
struct NtfyApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(delegate.model)
                .environment(delegate.model.servers)
                .environment(delegate.model.push)
                .environment(delegate.model.router)
                .modelContainer(delegate.model.container)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await delegate.model.refreshAll()
                await delegate.model.registerForPush()
            }
        }
    }
}
