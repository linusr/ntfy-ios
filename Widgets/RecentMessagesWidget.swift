import SwiftUI
import WidgetKit
import NtfyKit

@main
struct NtfyWidgets: WidgetBundle {
    var body: some Widget {
        RecentMessagesWidget()
    }
}

struct RecentMessagesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentMessages", provider: SnapshotProvider()) { entry in
            RecentMessagesView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Notifications")
        .description("The latest messages from your topics.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: RecentSnapshot
}

/// Reads the snapshot the app writes after every refresh; the app reloads timelines when it changes.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = RecentSnapshot.load()
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview && snapshot.entries.isEmpty ? .preview : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: RecentSnapshot.load())], policy: .never))
    }
}

struct RecentMessagesView: View {
    let snapshot: RecentSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "bell.fill").font(.caption)
                    Text(snapshot.unreadCount, format: .number).font(.title3.bold())
                }
            }
            .widgetURL(snapshot.entries.first.map { TopicStyle.topicLink($0.topicKey) })
        case .accessoryInline:
            if let latest = snapshot.entries.first {
                Label(latest.message.title ?? latest.topicTitle, systemImage: "bell.fill")
            } else {
                Label("No messages", systemImage: "bell")
            }
        case .accessoryRectangular:
            if let latest = snapshot.entries.first {
                VStack(alignment: .leading) {
                    Text(latest.topicTitle).font(.headline).widgetAccentable()
                    Text(NotificationFormatter.bodyText(latest.message)).font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(TopicStyle.topicLink(latest.topicKey))
            } else {
                Text("No messages").foregroundStyle(.secondary)
            }
        case .systemSmall:
            SmallView(snapshot: snapshot)
        default:
            ListView(snapshot: snapshot, limit: family == .systemLarge ? 6 : 3)
        }
    }
}

private struct SmallView: View {
    let snapshot: RecentSnapshot

    var body: some View {
        if let latest = snapshot.entries.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TopicBadge(entry: latest)
                    Spacer()
                    if snapshot.unreadCount > 0 {
                        Text(snapshot.unreadCount, format: .number)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .background(TopicStyle.color(latest.tint), in: .capsule)
                    }
                }
                Text(heading(latest)).font(.headline).lineLimit(2)
                Text(NotificationFormatter.bodyText(latest.message)).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Spacer(minLength: 0)
                Text(latest.message.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
            }
            .widgetURL(TopicStyle.topicLink(latest.topicKey))
        } else {
            EmptyWidgetView()
        }
    }
}

private struct ListView: View {
    let snapshot: RecentSnapshot
    let limit: Int

    var body: some View {
        if snapshot.entries.isEmpty {
            EmptyWidgetView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Notifications", systemImage: "bell.badge.fill").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if snapshot.unreadCount > 0 {
                        Text("\(snapshot.unreadCount) unread").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach(snapshot.entries.prefix(limit)) { entry in
                    Link(destination: TopicStyle.topicLink(entry.topicKey)) {
                        HStack(alignment: .top, spacing: 8) {
                            TopicBadge(entry: entry)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(heading(entry)).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Spacer()
                                    Text(entry.message.date, format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(.secondary)
                                }
                                Text(NotificationFormatter.bodyText(entry.message)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct TopicBadge: View {
    let entry: RecentSnapshot.Entry

    var body: some View {
        Image(systemName: entry.symbol)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(TopicStyle.color(entry.tint).gradient, in: .rect(cornerRadius: 6))
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bell.slash").font(.title2).foregroundStyle(.secondary)
            Text("No messages yet").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func heading(_ entry: RecentSnapshot.Entry) -> String {
    let emoji = entry.message.emojiTags.joined()
    let title = entry.message.title.flatMap { $0.isEmpty ? nil : $0 } ?? entry.topicTitle
    return emoji.isEmpty ? title : "\(emoji) \(title)"
}

extension RecentSnapshot {
    static let preview = RecentSnapshot(entries: [
        Entry(topicKey: "preview/alerts", topicTitle: "alerts", symbol: "chart.line.uptrend.xyaxis", tint: "pink",
              message: Message(id: "p1", time: Int64(Date.now.timeIntervalSince1970) - 120, topic: "alerts", title: "Deploy succeeded", message: "api v2.14.0 is live in production.", priority: 4, tags: ["rocket"])),
        Entry(topicKey: "preview/backups", topicTitle: "backups", symbol: "server.rack", tint: "blue",
              message: Message(id: "p2", time: Int64(Date.now.timeIntervalSince1970) - 3600, topic: "backups", title: "Nightly backup finished", message: "Backed up 1.2 TB in 42 minutes.", tags: ["white_check_mark"])),
        Entry(topicKey: "preview/home", topicTitle: "home", symbol: "house.fill", tint: "yellow",
              message: Message(id: "p3", time: Int64(Date.now.timeIntervalSince1970) - 7200, topic: "home", title: "Package delivered", message: "Left at the front door.", tags: ["package"])),
    ], unreadCount: 2)
}
