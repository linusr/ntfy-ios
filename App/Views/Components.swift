import SwiftUI
import NtfyKit

extension TopicTint {
    var color: Color { TopicStyle.color(rawValue) }
}

struct TopicIcon: View {
    let symbol: String
    let tint: TopicTint
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.color.gradient, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        switch priority {
        case .max:
            Label("Urgent", systemImage: "exclamationmark.2").foregroundStyle(.red)
        case .high:
            Label("High", systemImage: "exclamationmark").foregroundStyle(.orange)
        case .low, .min:
            Label("Low", systemImage: "arrow.down").foregroundStyle(.secondary)
        case .default:
            EmptyView()
        }
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.fill.tertiary, in: .capsule)
    }
}

/// Wrapping layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, point) in arrange(subviews, width: bounds.width).points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (points, CGSize(width: maxX, height: y + rowHeight))
    }
}
