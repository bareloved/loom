import SwiftUI

struct DailySummaryView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(summaries, id: \.category) { summary in
                HStack {
                    Text(summary.category)
                        .font(.callout)
                    Spacer()
                    Text(summary.formattedDuration)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if summaries.isEmpty {
                Text("No activity tracked yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
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
        return totals
            .map { CategorySummary(category: $0.key, totalDuration: $0.value) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }
}

private struct CategorySummary {
    let category: String
    let totalDuration: TimeInterval

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
