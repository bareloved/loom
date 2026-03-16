import SwiftUI
import ServiceManagement

@Observable
@MainActor
final class AppState {
    var calendarWriter = CalendarWriter()
    var calendarReader: CalendarReader?
    var activityMonitor = ActivityMonitor()
    var sessionEngine: SessionEngine?
    var isReady = false
    var accessibilityGranted = false
    var hotkeyManager = HotkeyManager()
    var idleReturnController = IdleReturnPanelController()
    @ObservationIgnored @AppStorage("showMenuBarText") var showMenuBarText = true
    @ObservationIgnored @AppStorage("goalCategory") var goalCategory = "Coding"
    @ObservationIgnored @AppStorage("goalHours") var goalHours = 0.0
    // appearance is read via @AppStorage in TimeTrackerApp struct directly
    var menuBarTitle: String = "⏱"
    private var menuBarTimer: Timer?

    func setup() async {
        let granted = await calendarWriter.requestAccess()
        if !granted {
            print("Calendar access not granted")
        }

        // Init calendar reader with shared event store
        calendarReader = CalendarReader(eventStore: calendarWriter.sharedEventStore)

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
        // Do NOT start monitor here — it starts when the user starts tracking

        // Hotkey
        hotkeyManager.onToggle = { [weak self] in
            self?.togglePause()
        }
        hotkeyManager.start()

        // Idle return
        activityMonitor.onIdleReturn = { [weak self] duration in
            guard let self, duration > 300 else { return } // Only for 5+ min idle
            self.idleReturnController.show(
                idleDuration: duration,
                onSelect: { label in
                    self.createIdleEvent(label: label, duration: duration)
                },
                onDismiss: { }
            )
        }

        // Menu bar text
        startMenuBarTimer()

        setupSleepWakeHandlers(engine: engine)
        setupTerminationHandler(engine: engine)

        isReady = true
    }

    // MARK: - Start/Stop Tracking

    func startTracking(intention: String? = nil) {
        sessionEngine?.startSession(intention: intention)
        activityMonitor.start()
    }

    func stopTracking() {
        sessionEngine?.stopSession()
        activityMonitor.stop()
    }

    // MARK: - Main Window (stub)

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Config

    func saveConfig(_ newConfig: CategoryConfig) {
        do {
            try CategoryConfigLoader.save(newConfig)
            // Rebuild engine with new config
            let wasTracking = sessionEngine?.isTracking ?? false
            let engine = SessionEngine(config: newConfig, calendarWriter: calendarWriter)
            self.sessionEngine = engine
            self.activityMonitor.onActivity = { [weak engine] record in
                engine?.process(record)
            }
            self.activityMonitor.onIdle = { [weak engine] in
                engine?.handleIdle(at: Date())
            }
            if wasTracking {
                engine.startSession()
            }
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    // MARK: - Sleep/Wake & Termination

    private func setupSleepWakeHandlers(engine: SessionEngine) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.sessionEngine?.isTracking == true else { return }
                engine.handleIdle(at: Date())
                self.activityMonitor.pause()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.sessionEngine?.isTracking == true else { return }
                self.activityMonitor.resume()
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
                if engine.isTracking {
                    engine.stopSession()
                }
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

    private var settingsWindow: NSWindow?

    func openSettings() {
        // If window already exists, just bring it forward
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let currentConfig: CategoryConfig
        do {
            currentConfig = try CategoryConfigLoader.loadOrCreateDefault()
        } catch {
            print("Failed to load config: \(error)")
            return
        }

        let settingsView = SettingsView(config: currentConfig) { [weak self] newConfig in
            self?.saveConfig(newConfig)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TimeTracker Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    func quit() {
        if sessionEngine?.isTracking == true {
            sessionEngine?.stopSession()
        }
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

    // appearanceScheme moved to TimeTrackerApp struct

    private func startMenuBarTimer() {
        updateMenuBarTitle()
        accessibilityGranted = AXIsProcessTrusted()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMenuBarTitle()
                self?.accessibilityGranted = AXIsProcessTrusted()
            }
        }
    }

    private func updateMenuBarTitle() {
        guard showMenuBarText else {
            menuBarTitle = "⏱"
            return
        }
        if activityMonitor.isPaused {
            menuBarTitle = "⏸ Paused"
            return
        }
        guard let session = sessionEngine?.currentSession else {
            menuBarTitle = "⏱"
            return
        }
        let duration = Date().timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        menuBarTitle = "⏱ \(hours):\(String(format: "%02d", minutes)) \(session.category)"
    }

    private func createIdleEvent(label: String, duration: TimeInterval) {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-duration)
        var session = Session(
            category: label,
            startTime: startTime,
            endTime: endTime,
            appsUsed: []
        )
        calendarWriter.createEvent(for: session)
        session.endTime = endTime
        calendarWriter.finalizeEvent(for: session)
    }
}

@main
struct TimeTrackerApp: App {
    @State private var appState = AppState()
    @AppStorage("appearance") private var appearance = "system"

    private var appearanceScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func applyAppearance() {
        switch appearance {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // follow system
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Group {
                if let engine = appState.sessionEngine {
                    MenuBarView(
                        sessionEngine: engine,
                        activityMonitor: appState.activityMonitor,
                        accessibilityGranted: appState.accessibilityGranted,
                        goalCategory: appState.goalCategory,
                        goalHours: appState.goalHours,
                        isTracking: engine.isTracking,
                        onStartTracking: { intention in appState.startTracking(intention: intention) },
                        onStopTracking: { appState.stopTracking() },
                        onOpenSettings: appState.openSettings,
                        onOpenWindow: { appState.openMainWindow() },
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
            .preferredColorScheme(appearanceScheme)
            .onChange(of: appearance) {
                applyAppearance()
            }
            .onAppear {
                applyAppearance()
            }
        } label: {
            Text(appState.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Window("TimeTracker", id: "main") {
            MainWindowView(appState: appState)
                .preferredColorScheme(appearanceScheme)
        }
        .defaultSize(width: 500, height: 700)
    }
}
