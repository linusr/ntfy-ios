import SwiftUI
import SwiftData
import NtfyKit

struct TopicView: View {
    let subscription: Subscription
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var isComposing = false
    @State private var isEditing = false
    @State private var isAddingDevice = false

    private var days: [(day: Date, messages: [StoredMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: subscription.messages) { calendar.startOfDay(for: $0.time) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.time > $1.time })
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                ForEach(days, id: \.day) { day in
                    Section {
                        ForEach(day.messages) { stored in
                            if let message = stored.message {
                                MessageCard(message: message, isUnread: !stored.isRead, tint: subscription.tint, server: subscription.serverURL)
                                    .contextMenu {
                                        Button("Copy", systemImage: "doc.on.doc") {
                                            UIPasteboard.general.string = message.message
                                        }
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            context.delete(stored)
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text(dayTitle(day.day))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if subscription.messages.isEmpty {
                EmptyTopicView(subscription: subscription)
            }
        }
        .navigationTitle(subscription.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh(subscription) }
        .task { await model.markRead(subscription) }
        .onChange(of: subscription.messages.count) {
            Task { await model.markRead(subscription) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Send Message", systemImage: "square.and.pencil") { isComposing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Edit Topic", systemImage: "pencil") { isEditing = true }
                    Button("Add Device Key", systemImage: "key") { isAddingDevice = true }
                    Button(subscription.isMuted ? "Unmute" : "Mute", systemImage: subscription.isMuted ? "bell" : "bell.slash") {
                        Task { await model.setMuted(subscription, !subscription.isMuted) }
                    }
                    ShareLink(item: subscription.serverURL.appending(path: subscription.topic)) {
                        Label("Share Topic URL", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $isComposing) { ComposeView(subscription: subscription) }
        .sheet(isPresented: $isEditing) { EditTopicView(subscription: subscription) }
        .sheet(isPresented: $isAddingDevice) { DeviceKeyView(subscription: subscription) }
    }
}

/// "Today", "Yesterday", the weekday within the last week, or the date.
private func dayTitle(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return String(localized: "Today") }
    if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
    if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
        return date.formatted(.dateTime.weekday(.wide))
    }
    return date.formatted(date: .abbreviated, time: .omitted)
}

private struct EmptyTopicView: View {
    let subscription: Subscription

    private var command: String {
        "curl -d \"Hello 👋\" \(subscription.serverURL.appending(path: subscription.topic).absoluteString)"
    }

    var body: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "tray")
        } description: {
            VStack(spacing: 12) {
                Text("Publish to this topic and messages show up here.")
                Text(command)
                    .font(.caption.monospaced())
                    .padding(10)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                    .textSelection(.enabled)
            }
        } actions: {
            Button("Copy Command", systemImage: "doc.on.doc") { UIPasteboard.general.string = command }
        }
    }
}
