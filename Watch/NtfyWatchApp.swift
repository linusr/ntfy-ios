import SwiftUI

@main
struct NtfyWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            RecentMessagesView()
                .environment(store)
        }
    }
}
