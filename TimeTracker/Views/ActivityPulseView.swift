import SwiftUI

struct ActivityPulseView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                RoundedRectangle(cornerRadius: 1)
                    .fill(slot.color)
                    .frame(height: max(2, 28 * slot.fillRatio))
            }
        }
        .frame(height: 28)
    }

    private var slots: [PulseSlot] {
        let allSessions = combinedSessions
        guard let first = allSessions.first else { return [] }

        let calendar = Calendar.current
        let now = Date()

        // Round down to nearest 15-min slot
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: first.startTime)
        let startMinute = (startComponents.minute ?? 0) / 15 * 15
        var slotStart = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                       minute: startMinute, second: 0,
                                       of: first.startTime) ?? first.startTime

        let slotDuration: TimeInterval = 15 * 60
        var result: [PulseSlot] = []

        while slotStart < now {
            let slotEnd = slotStart.addingTimeInterval(slotDuration)
            var categoryTimes: [String: TimeInterval] = [:]

            for session in allSessions {
                let sessionEnd = session.endTime ?? now
                let overlapStart = max(slotStart, session.startTime)
                let overlapEnd = min(slotEnd, sessionEnd)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)
                if overlap > 0 {
                    categoryTimes[session.category, default: 0] += overlap
                }
            }

            let totalActive = categoryTimes.values.reduce(0, +)
            let dominant = categoryTimes.max(by: { $0.value < $1.value })?.key ?? "Other"

            result.append(PulseSlot(
                fillRatio: min(1.0, totalActive / slotDuration),
                color: totalActive > 0 ? CategoryColors.color(for: dominant) : Color(white: 0.2)
            ))

            slotStart = slotEnd
        }

        return result
    }

    private var combinedSessions: [Session] {
        var all = sessions
        if let current = currentSession {
            all.append(current)
        }
        return all.sorted { $0.startTime < $1.startTime }
    }
}

private struct PulseSlot {
    let fillRatio: Double
    let color: Color
}
