import SwiftUI
import LoomKit

struct HistoryTabView: View {
    let appState: MobileAppState
    @State private var selectedDate = Date()
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var editingSession: Session?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    weekStrip
                    dailySummaryBar
                    sessionList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadSessions() }
            .onChange(of: selectedDate) {
                Task { await loadSessions() }
            }
        }
    }

    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!

        return HStack {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: today)

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .frame(width: 28, height: 28)
                            .background(isSelected ? CategoryColors.accent : Color.clear)
                            .foregroundStyle(isSelected ? .white : (isToday ? CategoryColors.accent : Theme.textSecondary))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var dailySummaryBar: some View {
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(selectedDate.formatted(.dateTime.weekday(.wide))) — \(hours)h \(minutes)m tracked")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if !sessions.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(sessions) { session in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CategoryColors.color(for: session.category))
                                .frame(width: max(2, geo.size.width * session.duration / max(totalDuration, 1)))
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if sessions.isEmpty {
                    Text("No sessions")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 40)
                } else {
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .contextMenu {
                                Button {
                                    editingSession = session
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task {
                                        await appState.deleteSession(id: session.id)
                                        await loadSessions()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditView(
                session: session,
                categories: appState.categoryConfig?.orderedCategoryNames ?? [],
                onSave: { updated in
                    Task {
                        await appState.updateSession(updated)
                        await loadSessions()
                    }
                    editingSession = nil
                },
                onCancel: { editingSession = nil }
            )
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.category)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationString(session.duration))
                    .font(.body)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(timeRange(session))
                    .font(.caption2)
                    .foregroundStyle(Theme.textQuaternary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Theme.border.frame(height: 1)
        }
    }

    private func loadSessions() async {
        isLoading = true
        sessions = await appState.fetchSessions(for: selectedDate)
        isLoading = false
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func timeRange(_ session: Session) -> String {
        let start = session.startTime.formatted(date: .omitted, time: .shortened)
        let end = (session.endTime ?? Date()).formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
