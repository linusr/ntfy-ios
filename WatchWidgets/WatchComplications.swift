import SwiftUI
import WidgetKit
import NtfyKit

@main
struct AlaiWatchWidgets: WidgetBundle {
    var body: some Widget {
        LatestMessageComplication()
    }
}

struct LatestMessageComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestMessage", provider: WatchSnapshotProvider()) { entry in
            ComplicationView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Latest Notification")
        .description("The newest message, or the number of unread messages.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: RecentSnapshot
}

struct WatchSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchSnapshotEntry {
        WatchSnapshotEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchSnapshotEntry) -> Void) {
        completion(WatchSnapshotEntry(date: .now, snapshot: RecentSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchSnapshotEntry>) -> Void) {
        completion(Timeline(entries: [WatchSnapshotEntry(date: .now, snapshot: RecentSnapshot.load())], policy: .never))
    }
}

struct ComplicationView: View {
    let snapshot: RecentSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "bell.fill").font(.caption2)
                    Text(snapshot.unreadCount, format: .number).font(.headline)
                }
            }
        case .accessoryCorner:
            Image(systemName: snapshot.unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                .widgetLabel { Text("\(snapshot.unreadCount) unread") }
        case .accessoryInline:
            if let latest = snapshot.entries.first {
                Label(latest.message.title ?? latest.topicTitle, systemImage: "bell.fill")
            } else {
                Label("No messages", systemImage: "bell")
            }
        default:
            if let latest = snapshot.entries.first {
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: latest.symbol)
                        Text(latest.topicTitle)
                    }
                    .font(.headline)
                    .widgetAccentable()
                    Text(NotificationFormatter.bodyText(latest.message)).font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No messages").foregroundStyle(.secondary)
            }
        }
    }
}
