import SwiftUI

struct DailySummaryView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summaries, id: \.category) { summary in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: summary.category))
                        .frame(width: 8, height: 8)

                    Text(summary.category)
                        .font(.system(size: 12))

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.trackFill)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(CategoryColors.color(for: summary.category))
                            .frame(width: max(2, 80 * summary.proportion), height: 4)
                    }
                    .frame(width: 80, height: 4)

                    Text(summary.formattedDuration)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            if summaries.isEmpty {
                EmptyStateView(title: "No activity today")
            }
        }
    }

    private var summaries: [CategorySummary] {
        var totals: [String: TimeInterval] = [:]
        for session in sessions {
            totals[session.category, default: 0] += session.duration
        }
        if let current = currentSession {
            totals[current.category, default: 0] += current.duration
        }

        let maxDuration = totals.values.max() ?? 1

        return totals
            .map { CategorySummary(
                category: $0.key,
                totalDuration: $0.value,
                proportion: $0.value / maxDuration
            )}
            .sorted { $0.totalDuration > $1.totalDuration }
    }
}

private struct CategorySummary {
    let category: String
    let totalDuration: TimeInterval
    let proportion: Double

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
