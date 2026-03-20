import SwiftUI

enum AppTab: String, CaseIterable {
    case today = "Today"
    case calendar = "Calendar"
    case stats = "Stats"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .today: return "clock"
        case .calendar: return "calendar"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    let appState: AppState

    @State private var selectedTab: AppTab = .today

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            Group {
                switch selectedTab {
                case .today:
                    if let engine = appState.sessionEngine {
                        TodayTabView(
                            sessionEngine: engine,
                            isTracking: engine.isTracking,
                            categories: Array((appState.categoryConfig?.categories.keys.sorted()) ?? []),
                            onStart: { category, intention in
                                appState.startTracking(category: category, intention: intention)
                            },
                            onStop: { appState.stopTracking() },
                            focusGuard: appState.focusGuard
                        )
                    } else {
                        Text("Starting up...")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .calendar:
                    if let engine = appState.sessionEngine {
                        CalendarTabView(
                            sessionEngine: engine,
                            calendarReader: appState.calendarReader,
                            calendarWriter: appState.calendarWriter,
                            categories: Array((try? CategoryConfigLoader.loadOrCreateDefault())?.categories.keys.sorted() ?? [])
                        )
                    }
                case .stats:
                    if let engine = appState.sessionEngine {
                        StatsTabView(
                            sessionEngine: engine,
                            calendarReader: appState.calendarReader
                        )
                    }
                case .settings:
                    if let currentConfig = try? CategoryConfigLoader.loadOrCreateDefault() {
                        SettingsTabView(config: currentConfig, calendarWriter: appState.calendarWriter, appState: appState) { newConfig in
                            appState.saveConfig(newConfig)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Mini player bar
            if let engine = appState.sessionEngine {
                MiniPlayerBar(
                    sessionEngine: engine,
                    onStart: { appState.showSessionPicker() },
                    onStop: { appState.stopTracking() }
                )
            }

            Divider()

            // Bottom tab bar
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(selectedTab == tab ? CategoryColors.accent : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Theme.background)
        .onAppear {
            appState.openWindowAction = openWindow
        }
    }
}
