import SwiftUI

struct FocusGoalView: View {
    let currentMinutes: Double
    let goalMinutes: Double
    let categoryName: String

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(currentMinutes / goalMinutes, 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Ring
            ZStack {
                Circle()
                    .stroke(CategoryColors.accent.opacity(0.12), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0 ? Color.green : CategoryColors.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                Text("\(progressPercent)%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CategoryColors.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Daily Focus Goal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Self.formatDuration(currentMinutes)) of \(Self.formatDuration(goalMinutes)) \(categoryName.lowercased()) target")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(8)
        .background(CategoryColors.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CategoryColors.accent.opacity(0.1), lineWidth: 1)
        )
    }

    private static func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
