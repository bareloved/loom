import SwiftUI

struct WeekStripView: View {
    let selectedDate: Date
    let dailyTotals: [Date: TimeInterval]
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current
    private let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    private var weekDays: [Date] {
        // Find Monday of selectedDate's week
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                let dayStart = calendar.startOfDay(for: day)
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let hours = (dailyTotals[dayStart] ?? 0) / 3600

                Button(action: { onSelectDate(day) }) {
                    VStack(spacing: 2) {
                        Text(dayLabels[index])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)

                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 16))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textPrimary)

                        Text(String(format: "%.1fh", hours))
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)

                        if isToday {
                            Circle()
                                .fill(CategoryColors.accent)
                                .frame(width: 4, height: 4)
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        isSelected
                            ? CategoryColors.accent.opacity(0.1)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
