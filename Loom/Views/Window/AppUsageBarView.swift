// Loom/Views/Window/AppUsageBarView.swift
import SwiftUI

struct AppUsageBarView: View {
    let appsUsed: [AppUsage]
    let totalDuration: TimeInterval

    // MARK: - Color Palette

    static let appPalette: [Color] = [
        Color(hex: 0x7b8db8), // dusty blue
        Color(hex: 0xc9956a), // warm clay
        Color(hex: 0x5a9a6e), // matte green
        Color(hex: 0xa07cba), // dusty purple
        Color(hex: 0xc47878), // matte rose
        Color(hex: 0x6da89a), // sage
        Color(hex: 0xc4a558), // soft amber
        Color(hex: 0x7a8a8a), // slate
    ]

    static let otherColor = Color(hex: 0x9a958e) // warm gray

    // MARK: - Data Model

    struct BarItem: Equatable {
        let label: String
        let duration: TimeInterval
        let proportion: Double
        let color: Color
    }

    // MARK: - Grouping Logic

    static func groupedItems(from apps: [AppUsage], totalDuration: TimeInterval) -> [BarItem] {
        guard !apps.isEmpty else { return [] }

        let sorted = apps.sorted { $0.duration > $1.duration }

        // Zero duration: equal proportions, no grouping
        if totalDuration <= 0 {
            let equalProportion = 1.0 / Double(sorted.count)
            return sorted.enumerated().map { index, app in
                BarItem(
                    label: app.appName,
                    duration: app.duration,
                    proportion: equalProportion,
                    color: appPalette[index % appPalette.count]
                )
            }
        }

        let threshold = totalDuration * 0.02 // 2%
        var major: [AppUsage] = []
        var minor: [AppUsage] = []

        for app in sorted {
            if app.duration >= threshold {
                major.append(app)
            } else {
                minor.append(app)
            }
        }

        // If all apps are below threshold, show all individually
        if major.isEmpty {
            return sorted.enumerated().map { index, app in
                BarItem(
                    label: app.appName,
                    duration: app.duration,
                    proportion: app.duration / totalDuration,
                    color: appPalette[index % appPalette.count]
                )
            }
        }

        var items: [BarItem] = major.enumerated().map { index, app in
            BarItem(
                label: app.appName,
                duration: app.duration,
                proportion: app.duration / totalDuration,
                color: appPalette[index % appPalette.count]
            )
        }

        // Group minor apps into "Other"
        if !minor.isEmpty {
            let otherDuration = minor.reduce(0) { $0 + $1.duration }
            items.append(BarItem(
                label: "Other",
                duration: otherDuration,
                proportion: otherDuration / totalDuration,
                color: otherColor
            ))
        }

        return items
    }

    // MARK: - View

    private var items: [BarItem] {
        Self.groupedItems(from: appsUsed, totalDuration: totalDuration)
    }

    private var hasAnyDuration: Bool {
        totalDuration > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stacked bar
            GeometryReader { geo in
                let totalGaps = CGFloat(max(items.count - 1, 0)) * 1
                let barWidth = geo.size.width - totalGaps
                HStack(spacing: 1) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.color)
                            .frame(width: max(4, barWidth * CGFloat(item.proportion)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 20)

            // Legend
            FlowLayout(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                        if hasAnyDuration {
                            Text(formatDuration(item.duration))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes == 0 { return "< 1m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if remainingMinutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - FlowLayout

/// A wrapping horizontal layout that moves items to the next line when they exceed available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { total, row in
            total + row.height + (total > 0 ? spacing / 2 : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing / 2
        }
    }

    private struct Row {
        var indices: [Int]
        var height: CGFloat
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row(indices: [], height: 0)
        var currentX: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !currentRow.indices.isEmpty && currentX + size.width > maxWidth {
                rows.append(currentRow)
                currentRow = Row(indices: [], height: 0)
                currentX = 0
            }
            currentRow.indices.append(index)
            currentRow.height = max(currentRow.height, size.height)
            currentX += size.width + spacing
        }
        if !currentRow.indices.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
