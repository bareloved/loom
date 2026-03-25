import SwiftUI
import LoomKit

@Observable
@MainActor
final class MobileAppState {
    var syncEngine = SyncEngine(source: "ios")
    var categoryConfig: CategoryConfig?
    var currentSession: Session?      // locally started session
    var remoteSession: Session?       // fetched from CloudKit when Mac is tracking
    var isReady = false

    func setup() async {
        await syncEngine.setupSubscriptions()
        await refreshActiveState()

        if let remoteConfig = await syncEngine.fetchCategoryConfig() {
            categoryConfig = remoteConfig
        } else {
            categoryConfig = try? CategoryConfigLoader.loadDefault()
        }

        isReady = true
    }

    func refreshActiveState() async {
        await syncEngine.fetchActiveState()
        // If there's an active remote session, fetch its details
        if let activeID = syncEngine.activeSessionID, currentSession == nil {
            remoteSession = await syncEngine.fetchSession(by: activeID)
        } else {
            remoteSession = nil
        }
    }

    func startSession(category: String, intention: String?) async {
        // Check for existing active session
        await syncEngine.fetchActiveState()
        if syncEngine.activeSessionID != nil {
            // Caller should handle this -- prompt user first
            return
        }

        let session = Session(
            category: category,
            startTime: Date(),
            appsUsed: [],
            intention: intention,
            source: "ios"
        )
        currentSession = session
        await syncEngine.publishSessionStart(session)
    }

    func stopSession() async {
        if var session = currentSession {
            session.endTime = Date()
            await syncEngine.publishSessionStop(session)
            currentSession = nil
        } else if syncEngine.activeSessionID != nil {
            // Remote stop
            await syncEngine.forceStopRemoteSession()
        }
        remoteSession = nil
    }

    func fetchSessions(for date: Date) async -> [Session] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return await syncEngine.fetchSessions(from: start, to: end)
    }
}

@main
struct LoomMobileApp: App {
    @State private var appState = MobileAppState()
    @AppStorage("appearance") private var appearance = "system"

    private var appearanceScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if appState.isReady {
                ContentView(appState: appState)
                    .preferredColorScheme(appearanceScheme)
            } else {
                ProgressView("Loading...")
                    .task { await appState.setup() }
            }
        }
    }
}

struct ContentView: View {
    let appState: MobileAppState

    var body: some View {
        TabView {
            NowTabView(appState: appState)
                .tabItem {
                    Label("Now", systemImage: "circle.fill")
                }
            HistoryTabView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
            SettingsTabView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(CategoryColors.accent)
    }
}
