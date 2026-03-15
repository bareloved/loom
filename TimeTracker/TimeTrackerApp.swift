import SwiftUI
import ServiceManagement

@Observable
@MainActor
final class AppState {
    var calendarWriter = CalendarWriter()
    var activityMonitor = ActivityMonitor()
    var sessionEngine: SessionEngine?
    var isReady = false
    var accessibilityGranted = false

    func setup() async {
        let granted = await calendarWriter.requestAccess()
        if !granted {
            print("Calendar access not granted")
        }

        let config: CategoryConfig
        do {
            config = try CategoryConfigLoader.loadOrCreateDefault()
        } catch {
            print("Failed to load config: \(error)")
            return
        }

        accessibilityGranted = AXIsProcessTrusted()

        let engine = SessionEngine(config: config, calendarWriter: calendarWriter)
        self.sessionEngine = engine

        activityMonitor.onActivity = { [weak engine] record in
            engine?.process(record)
        }
        activityMonitor.onIdle = { [weak engine] in
            engine?.handleIdle(at: Date())
        }
        activityMonitor.start()

        setupSleepWakeHandlers(engine: engine)
        setupTerminationHandler(engine: engine)

        isReady = true
    }

    private func setupSleepWakeHandlers(engine: SessionEngine) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                engine.handleIdle(at: Date())
                self?.activityMonitor.pause()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.activityMonitor.resume()
            }
        }
    }

    private func setupTerminationHandler(engine: SessionEngine) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                engine.finalizeCurrentSession()
            }
        }
    }

    func togglePause() {
        if activityMonitor.isPaused {
            activityMonitor.resume()
        } else {
            activityMonitor.pause()
            sessionEngine?.handleIdle(at: Date())
        }
    }

    func openSettings() {
        let configPath = CategoryConfigLoader.defaultConfigPath.path
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    func quit() {
        sessionEngine?.finalizeCurrentSession()
        NSApplication.shared.terminate(nil)
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}

@main
struct TimeTrackerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TimeTracker", systemImage: "clock.badge.checkmark") {
            if let engine = appState.sessionEngine {
                MenuBarView(
                    sessionEngine: engine,
                    activityMonitor: appState.activityMonitor,
                    accessibilityGranted: appState.accessibilityGranted,
                    launchAtLoginEnabled: appState.launchAtLoginEnabled,
                    onPauseResume: appState.togglePause,
                    onOpenSettings: appState.openSettings,
                    onToggleLaunchAtLogin: appState.toggleLaunchAtLogin,
                    onQuit: appState.quit
                )
            } else {
                VStack {
                    Text("Starting up...")
                        .padding()
                }
                .task {
                    await appState.setup()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
