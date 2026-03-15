import SwiftUI

struct WeeklySummaryView: View {
    let weeklyStats: [String: TimeInterval]
    let todaySessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("This Week")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(totalFormatted)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            // Category breakdown (same style as DailySummaryView)
            ForEach(summaries, id: \.category) { summary in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: summary.category))
                        .frame(width: 8, height: 8)

                    Text(summary.category)
                        .font(.system(size: 12))

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.trackFill)
                            .frame(width: geo.size.width, height: 4)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(CategoryColors.color(for: summary.category))
                                    .frame(width: geo.size.width * summary.proportion, height: 4)
                            }
                    }
                    .frame(height: 4)

                    Text(summary.formattedDuration)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            if summaries.isEmpty {
                Text("No data for this week yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var combinedStats: [String: TimeInterval] {
        var totals = weeklyStats
        // Add today's in-memory data
        for session in todaySessions {
            totals[session.category, default: 0] += session.duration
        }
        if let current = currentSession {
            totals[current.category, default: 0] += current.duration
        }
        return totals
    }

    private var summaries: [WeekCategorySummary] {
        let totals = combinedStats
        let maxDuration = totals.values.max() ?? 1
        return totals
            .map { WeekCategorySummary(
                category: $0.key,
                totalDuration: $0.value,
                proportion: $0.value / maxDuration
            )}
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    private var totalFormatted: String {
        let total = combinedStats.values.reduce(0, +)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m total" }
        return "\(minutes)m total"
    }
}

private struct WeekCategorySummary {
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
