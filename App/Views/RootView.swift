import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(ServerDirectory.self) private var servers
    @Environment(Router.self) private var router
    @Query(sort: \Subscription.createdAt) private var subscriptions: [Subscription]

    var body: some View {
        @Bindable var router = router
        if servers.servers.isEmpty {
            OnboardingView()
        } else {
            NavigationSplitView {
                TopicListView(selection: $router.selectedTopicKey)
            } detail: {
                if let subscription = subscriptions.first(where: { $0.key == router.selectedTopicKey }) {
                    TopicView(subscription: subscription)
                        .id(subscription.key)
                } else {
                    ContentUnavailableView("Select a Topic", systemImage: "bell.badge")
                }
            }
        }
    }
}

struct OnboardingView: View {
    @State private var isAddingServer = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.waveform.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 3)))
            VStack(spacing: 8) {
                Text("Your notifications,\nyour server")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Connect to your ntfy server to receive instant notifications from scripts, services and devices.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                isAddingServer = true
            } label: {
                Text("Connect Server").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(32)
        .sheet(isPresented: $isAddingServer) {
            AddServerView()
        }
    }
}
