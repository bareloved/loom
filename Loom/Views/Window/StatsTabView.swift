import SwiftUI

struct StatsTabView: View {
    let sessionEngine: SessionEngine
    let calendarReader: CalendarReader?

    @State private var selectedDate = Date()
    @State private var weekSessions: [Date: [Session]] = [:]
    @State private var filterCategory: String?

    private let calendar = Calendar.current

    private var allWeekSessions: [Session] {
        var sessions: [Session] = []
        for (date, daySessions) in weekSessions {
            if calendar.isDateInToday(date) {
                continue // will add live data instead
            }
            sessions.append(contentsOf: daySessions)
        }
        // Add today's live data
        sessions.append(contentsOf: sessionEngine.todaySessions)
        if let current = sessionEngine.currentSession {
            sessions.append(current)
        }
        if let filter = filterCategory {
            sessions = sessions.filter { $0.category == filter }
        }
        return sessions
    }

    private var dailyTotals: [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for (date, sessions) in weekSessions {
            totals[date] = sessions.reduce(0) { $0 + $1.duration }
        }
        let todayStart = calendar.startOfDay(for: Date())
        let liveDuration = sessionEngine.todaySessions.reduce(0.0) { $0 + $1.duration }
            + (sessionEngine.currentSession?.duration ?? 0)
        totals[todayStart] = max(totals[todayStart] ?? 0, liveDuration)
        return totals
    }

    private var categoryDistribution: [(category: String, duration: TimeInterval, ratio: Double)] {
        let sessions = allWeekSessions
        var totals: [String: TimeInterval] = [:]
        for s in sessions {
            totals[s.category, default: 0] += s.duration
        }
        let totalDuration = totals.values.reduce(0, +)
        guard totalDuration > 0 else { return [] }
        return totals.sorted { $0.value > $1.value }
            .map { (category: $0.key, duration: $0.value, ratio: $0.value / totalDuration) }
    }

    private var intentionDistribution: [(intention: String, duration: TimeInterval, ratio: Double, count: Int)] {
        let sessions = allWeekSessions
        var totals: [String: (duration: TimeInterval, count: Int)] = [:]
        for s in sessions {
            let key = s.intention ?? "No intention"
            totals[key, default: (0, 0)].duration += s.duration
            totals[key, default: (0, 0)].count += 1
        }
        let totalDuration = totals.values.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return [] }
        return totals.sorted { $0.value.duration > $1.value.duration }
            .map { (intention: $0.key, duration: $0.value.duration, ratio: $0.value.duration / totalDuration, count: $0.value.count) }
    }

    private var allCategories: [String] {
        Array(Set(allWeekSessions.map(\.category))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Week navigation
                HStack {
                    Button(action: { shiftWeek(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Today") {
                        selectedDate = Date()
                        loadWeekSessions()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CategoryColors.accent)

                    Spacer()

                    Button(action: { shiftWeek(1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }

                // Week strip
                WeekStripView(
                    selectedDate: selectedDate,
                    dailyTotals: dailyTotals,
                    onSelectDate: { selectedDate = $0 }
                )

                // Filter toggle
                HStack {
                    Text("Filter:")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)

                    Button(action: { filterCategory = nil }) {
                        Text("All")
                            .font(.system(size: 11, weight: filterCategory == nil ? .semibold : .regular))
                            .foregroundStyle(filterCategory == nil ? CategoryColors.accent : Theme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    ForEach(allCategories, id: \.self) { cat in
                        Button(action: { filterCategory = cat }) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(CategoryColors.color(for: cat))
                                    .frame(width: 6, height: 6)
                                Text(cat)
                                    .font(.system(size: 11, weight: filterCategory == cat ? .semibold : .regular))
                                    .foregroundStyle(filterCategory == cat ? CategoryColors.accent : Theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }

                // Category Distribution card
                statsCard(title: "Category Distribution") {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("CATEGORY")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("RATIO")
                                .frame(width: 100)
                            Text("CHANGE")
                                .frame(width: 60)
                            Text("TIME")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 6)

                        ForEach(categoryDistribution, id: \.category) { item in
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(CategoryColors.color(for: item.category))
                                        .frame(width: 8, height: 8)
                                    Text(item.category)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Progress bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.trackFill)
                                        .frame(width: 100, height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(CategoryColors.color(for: item.category))
                                        .frame(width: max(100 * CGFloat(item.ratio), 4), height: 6)
                                }
                                .frame(width: 100)

                                Text("\u{2014}")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 60)

                                Text(formatDuration(item.duration))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // By Intention card
                statsCard(title: "By Intention") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("INTENTION")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("RATIO")
                                .frame(width: 100)
                            Text("SESSIONS")
                                .frame(width: 60)
                            Text("TIME")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 6)

                        ForEach(intentionDistribution, id: \.intention) { item in
                            HStack {
                                Text(item.intention)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.trackFill)
                                        .frame(width: 100, height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(CategoryColors.accent)
                                        .frame(width: max(100 * CGFloat(item.ratio), 4), height: 6)
                                }
                                .frame(width: 100)

                                Text("\(item.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 60)

                                Text(formatDuration(item.duration))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadWeekSessions() }
        .onChange(of: selectedDate) { loadWeekSessions() }
    }

    @ViewBuilder
    private func statsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(light: .white, dark: Color(hex: 0x2a2826)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }

    private func shiftWeek(_ delta: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: delta, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadWeekSessions() {
        weekSessions = calendarReader?.sessionsForWeek(containing: selectedDate) ?? [:]
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
