import SwiftUI

struct VerticalTimelineView: View {
    let sessions: [Session]
    let isToday: Bool
    var backgroundEvents: [CalendarEvent] = []
    @Binding var visibleHourRange: ClosedRange<CGFloat>
    var selectedSessionId: Binding<String?> = .constant(nil)
    var onSessionDoubleClick: ((Session) -> Void)? = nil

    private let hourHeight: CGFloat = 60
    private let labelWidth: CGFloat = 40

    @State private var currentTime = Date()

    private var displayHours: ClosedRange<Int> {
        0...23
    }

    private var dayStart: Date {
        let cal = Calendar.current
        if let first = sessions.first {
            return cal.startOfDay(for: first.startTime)
        }
        return cal.startOfDay(for: Date())
    }

    private func yOffset(for date: Date) -> CGFloat {
        let interval = date.timeIntervalSince(dayStart)
        let hours = interval / 3600
        return CGFloat(hours - Double(displayHours.lowerBound)) * hourHeight
    }

    var body: some View {
        let totalHeight = CGFloat(displayHours.count) * hourHeight

        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    // Left column: hour labels + calendar events
                    leftColumn(totalHeight: totalHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: totalHeight, alignment: .topLeading)
                        .clipped()

                    // Divider
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 0.5, height: totalHeight)

                    // Right column: Loom sessions
                    rightColumn(totalHeight: totalHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: totalHeight, alignment: .topLeading)
                        .clipped()
                }
                .background(
                    GeometryReader { contentGeo in
                        let offset = contentGeo.frame(in: .named("timelineScroll")).origin.y
                        Color.clear
                            .onChange(of: offset) { updateVisibleRange(scrollOffset: offset, totalHeight: totalHeight) }
                            .onAppear { updateVisibleRange(scrollOffset: offset, totalHeight: totalHeight) }
                    }
                )
            }
            .coordinateSpace(name: "timelineScroll")
            .background(
                GeometryReader { scrollGeo in
                    Color.clear.onAppear { scrollViewHeight = scrollGeo.size.height }
                        .onChange(of: scrollGeo.size.height) { scrollViewHeight = scrollGeo.size.height }
                }
            )
            .onAppear {
                if isToday {
                    let currentHour = Calendar.current.component(.hour, from: currentTime)
                    proxy.scrollTo(max(currentHour - 1, displayHours.lowerBound), anchor: .top)
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                if isToday { currentTime = Date() }
            }
        }
    }

    @ViewBuilder
    private func leftColumn(totalHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let eventWidth = geo.size.width - labelWidth - 8

            ZStack(alignment: .topLeading) {
                // Hour labels and grid lines
                ForEach(Array(displayHours), id: \.self) { hour in
                    HStack(spacing: 0) {
                        Text(String(format: "%d:00", hour))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: labelWidth, alignment: .trailing)

                        Rectangle()
                            .fill(Theme.border)
                            .frame(height: 0.5)
                    }
                    .offset(y: CGFloat(hour - displayHours.lowerBound) * hourHeight)
                    .id(hour)
                }

                // Calendar events
                ForEach(backgroundEvents) { event in
                    let top = yOffset(for: event.startDate)
                    let height = max(CGFloat(event.endDate.timeIntervalSince(event.startDate) / 3600) * hourHeight, 20)

                    calendarEventBlock(event: event, height: height)
                        .frame(width: eventWidth)
                        .offset(x: labelWidth + 8, y: top)
                }

                // Current time indicator
                if isToday {
                    let y = yOffset(for: currentTime)
                    HStack(spacing: 4) {
                        Spacer().frame(width: labelWidth - 4)
                        Text(timeFormatter.string(from: currentTime))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(CategoryColors.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(CategoryColors.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Rectangle()
                            .fill(CategoryColors.accent)
                            .frame(height: 1.5)
                    }
                    .offset(y: y - 6)
                }
            }
        }
    }

    @ViewBuilder
    private func rightColumn(totalHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let sessionWidth = geo.size.width - 16

            ZStack(alignment: .topLeading) {
                // Grid lines
                ForEach(Array(displayHours), id: \.self) { hour in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                        .offset(y: CGFloat(hour - displayHours.lowerBound) * hourHeight)
                }

                // Session blocks
                ForEach(sessions) { session in
                    let top = yOffset(for: session.startTime)
                    let end = session.endTime ?? currentTime
                    let height = max(CGFloat(end.timeIntervalSince(session.startTime) / 3600) * hourHeight, 20)

                    sessionBlock(session: session, height: height)
                        .frame(width: sessionWidth)
                        .offset(x: 8, y: top)
                }

                // Current time line
                if isToday {
                    let y = yOffset(for: currentTime)
                    Rectangle()
                        .fill(CategoryColors.accent)
                        .frame(height: 1.5)
                        .offset(y: y)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionBlock(session: Session, height: CGFloat) -> some View {
        let color = CategoryColors.color(for: session.category)
        let isSelected = selectedSessionId.wrappedValue == session.id.uuidString

        VStack(alignment: .leading, spacing: 2) {
            Text(session.category)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)

            Text(timeRange(session))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(color.opacity(isSelected ? 0.85 : 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.5), lineWidth: 2)
            }
        }
        .onTapGesture(count: 2) {
            onSessionDoubleClick?(session)
        }
        .onTapGesture(count: 1) {
            selectedSessionId.wrappedValue = session.id.uuidString
        }
    }

    @ViewBuilder
    private func calendarEventBlock(event: CalendarEvent, height: CGFloat) -> some View {
        let color = Color(nsColor: event.color)
        Text(event.title)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func timeRange(_ session: Session) -> String {
        let start = timeFormatter.string(from: session.startTime)
        let end = timeFormatter.string(from: session.endTime ?? currentTime)
        return "\(start) - \(end)"
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    @State private var scrollViewHeight: CGFloat = 400

    private func updateVisibleRange(scrollOffset: CGFloat, totalHeight: CGFloat) {
        let startHour = CGFloat(displayHours.lowerBound)
        let scrolledPx = -scrollOffset
        let visibleStart = startHour + scrolledPx / hourHeight
        let visibleEnd = visibleStart + scrollViewHeight / hourHeight
        let clamped = max(visibleStart, 0)...min(visibleEnd, 24)
        visibleHourRange = clamped
    }
}
