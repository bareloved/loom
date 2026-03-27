import SwiftUI
import LoomKit

struct SessionDetailView: View {
    let session: Session

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.category)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(CategoryColors.color(for: session.category))

                        if let intention = session.intention, !intention.isEmpty {
                            Text(intention)
                                .font(.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    HStack {
                        Label {
                            Text(durationString(session.duration))
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .foregroundStyle(Theme.textPrimary)

                        Spacer()

                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    }

                    if !session.appsUsed.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apps Used")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            FlowLayout(spacing: 6) {
                                ForEach(session.appsUsed) { appUsage in
                                    Text(appUsage.appName)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.trackFill)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }

                    if !session.distractions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distractions")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            ForEach(session.distractions) { d in
                                HStack {
                                    Text(d.appName)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(durationString(d.duration))
                                        .foregroundStyle(Theme.textTertiary)
                                    if d.snoozed {
                                        Image(systemName: "moon.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.textQuaternary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    if let source = session.source {
                        Text("Tracked on \(source == "mac" ? "Mac" : "iPhone")")
                            .font(.caption)
                            .foregroundStyle(Theme.textQuaternary)
                    }
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeRange: String {
        let start = session.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = (session.endTime ?? Date()).formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
