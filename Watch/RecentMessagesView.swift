import SwiftUI
import NtfyKit

struct RecentMessagesView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        NavigationStack {
            List(store.entries) { entry in
                NavigationLink {
                    MessageDetailView(entry: entry)
                } label: {
                    MessageRow(entry: entry)
                }
            }
            .navigationTitle("ntfy")
            .overlay {
                if store.entries.isEmpty {
                    ContentUnavailableView("No Messages", systemImage: "bell", description: Text("Messages from your iPhone appear here."))
                }
            }
        }
    }
}

private struct MessageRow: View {
    let entry: WatchSnapshot.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: entry.symbol)
                    .foregroundStyle(tintColor(entry.tint))
                Text(entry.topicTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.message.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let title = heading {
                Text(title).font(.headline).lineLimit(1)
            }
            Text(NotificationFormatter.bodyText(entry.message))
                .font(.footnote)
                .lineLimit(3)
        }
    }

    private var heading: String? {
        let emoji = entry.message.emojiTags.joined()
        let title = entry.message.title ?? ""
        let text = [emoji, title].filter { !$0.isEmpty }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}

private struct MessageDetailView: View {
    let entry: WatchSnapshot.Entry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let title = entry.message.title, !title.isEmpty {
                    Text(entry.message.emojiTags.joined() + " " + title).font(.headline)
                }
                Text(NotificationFormatter.bodyText(entry.message))
                Text(entry.message.date, format: .dateTime.weekday().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entry.topicTitle)
    }
}

private func tintColor(_ name: String) -> Color {
    switch name {
    case "indigo": .indigo
    case "purple": .purple
    case "pink": .pink
    case "red": .red
    case "orange": .orange
    case "yellow": .yellow
    case "green": .green
    case "mint": .mint
    case "teal": .teal
    case "gray": .gray
    default: .blue
    }
}
