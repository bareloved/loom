import SwiftUI

struct TimelineBarView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(spacing: 4) {
            // Time labels
            HStack {
                Text(startTimeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
                Spacer()
                Text(midTimeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
                Spacer()
                Text("Now")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
            }

            // Timeline bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segment.color)
                            .frame(width: max(2, geo.size.width * segment.proportion))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var allSessions: [Session] {
        var all = sessions
        if let current = currentSession {
            all.append(current)
        }
        return all.sorted { $0.startTime < $1.startTime }
    }

    private var segments: [TimelineSegment] {
        let sorted = allSessions
        guard let first = sorted.first else { return [] }

        let now = Date()
        let totalDuration = now.timeIntervalSince(first.startTime)
        guard totalDuration > 0 else { return [] }

        var result: [TimelineSegment] = []

        for (i, session) in sorted.enumerated() {
            // Add idle gap before this session
            let gapStart = i == 0 ? first.startTime : (sorted[i-1].endTime ?? now)
            let gapDuration = session.startTime.timeIntervalSince(gapStart)
            if gapDuration > 30 {
                result.append(TimelineSegment(
                    proportion: gapDuration / totalDuration,
                    color: Color(white: 0.23).opacity(0.4)
                ))
            }

            // Add session
            let sessionEnd = session.endTime ?? now
            let sessionDuration = sessionEnd.timeIntervalSince(session.startTime)
            result.append(TimelineSegment(
                proportion: sessionDuration / totalDuration,
                color: CategoryColors.color(for: session.category)
            ))
        }

        return result
    }

    private var startTimeLabel: String {
        guard let first = allSessions.first else { return "" }
        return Self.timeFormatter.string(from: first.startTime)
    }

    private var midTimeLabel: String {
        guard let first = allSessions.first else { return "" }
        let mid = first.startTime.addingTimeInterval(Date().timeIntervalSince(first.startTime) / 2)
        return Self.timeFormatter.string(from: mid)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

private struct TimelineSegment {
    let proportion: Double
    let color: Color
}
