import SwiftUI

@main
struct AlaiApp: App {
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
                .onOpenURL { url in
                    delegate.model.router.open(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            let model = delegate.model
            switch phase {
            case .active:
                Task {
                    await model.refreshAll()
                    await model.registerForPush()
                    model.setLiveUpdates(active: true)
                }
            case .background:
                model.setLiveUpdates(active: false)
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
