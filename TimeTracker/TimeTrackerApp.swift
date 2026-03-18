import SwiftUI
import ServiceManagement

struct MenuBarIconGroup: Identifiable {
    let name: String
    let icons: [MenuBarIcon]
    var id: String { name }
}

struct MenuBarIcon: Identifiable, Equatable {
    let label: String
    let idleIcon: String
    let activeIcon: String
    var id: String { label }

    static let allGroups: [MenuBarIconGroup] = [
        MenuBarIconGroup(name: "Time", icons: [
            MenuBarIcon(label: "Clock", idleIcon: "clock", activeIcon: "clock.fill"),
            MenuBarIcon(label: "Stopwatch", idleIcon: "stopwatch", activeIcon: "stopwatch.fill"),
            MenuBarIcon(label: "Timer", idleIcon: "timer", activeIcon: "timer.circle.fill"),
            MenuBarIcon(label: "Hourglass", idleIcon: "hourglass", activeIcon: "hourglass.bottomhalf.filled"),
        ]),
        MenuBarIconGroup(name: "Nature", icons: [
            MenuBarIcon(label: "Sunrise", idleIcon: "sunrise", activeIcon: "sunrise.fill"),
            MenuBarIcon(label: "Sun & Moon", idleIcon: "moon", activeIcon: "sun.max.fill"),
            MenuBarIcon(label: "Flame", idleIcon: "flame", activeIcon: "flame.fill"),
            MenuBarIcon(label: "Leaf", idleIcon: "leaf", activeIcon: "leaf.fill"),
            MenuBarIcon(label: "Drop", idleIcon: "drop", activeIcon: "drop.fill"),
        ]),
        MenuBarIconGroup(name: "Activity", icons: [
            MenuBarIcon(label: "Bolt", idleIcon: "bolt", activeIcon: "bolt.fill"),
            MenuBarIcon(label: "Circle", idleIcon: "circle", activeIcon: "circle.fill"),
            MenuBarIcon(label: "Target", idleIcon: "scope", activeIcon: "target"),
            MenuBarIcon(label: "Waveform", idleIcon: "waveform.path", activeIcon: "waveform.path.ecg.rectangle.fill"),
        ]),
        MenuBarIconGroup(name: "Focus", icons: [
            MenuBarIcon(label: "Eye", idleIcon: "eye.slash", activeIcon: "eye.fill"),
            MenuBarIcon(label: "Brain", idleIcon: "brain", activeIcon: "brain.fill"),
            MenuBarIcon(label: "Lightbulb", idleIcon: "lightbulb", activeIcon: "lightbulb.fill"),
        ]),
        MenuBarIconGroup(name: "Other", icons: [
            MenuBarIcon(label: "Star", idleIcon: "star", activeIcon: "star.fill"),
            MenuBarIcon(label: "Heart", idleIcon: "heart", activeIcon: "heart.fill"),
            MenuBarIcon(label: "Diamond", idleIcon: "diamond", activeIcon: "diamond.fill"),
            MenuBarIcon(label: "Sparkle", idleIcon: "sparkle", activeIcon: "sparkles"),
        ]),
    ]

    static let allIcons: [MenuBarIcon] = allGroups.flatMap(\.icons)

    static func named(_ name: String) -> MenuBarIcon {
        allIcons.first { $0.label == name } ?? allIcons[0]
    }
}

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
    var launchPopupController = LaunchPopupController()
    @ObservationIgnored @AppStorage("showMenuBarText") var showMenuBarText = true
    @ObservationIgnored @AppStorage("goalCategory") var goalCategory = "Coding"
    @ObservationIgnored @AppStorage("goalHours") var goalHours = 0.0
    @ObservationIgnored @AppStorage("menuBarIcon") private var _storedMenuBarIcon = "Clock"
    var menuBarIconName: String = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "Clock"
    var menuBarTitle: String = ""
    var menuBarIconSystemName: String = "clock"
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

        accessibilityGranted = Self.testAccessibility()

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
        setupWindowObservers()

        // Show launch popup
        launchPopupController.show(
            onStart: { [weak self] intention in
                self?.startTracking(intention: intention)
                self?.openMainWindow()
            },
            onDismiss: { }
        )

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

    // MARK: - Main Window

    var openWindowAction: OpenWindowAction?

    func openMainWindow() {
        openWindowAction?(id: "main")
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
        window.title = "Loom Settings"
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

    func setupWindowObservers() {
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            guard let window = notification.object as? NSWindow, window.title == "Loom" else { return }
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.regular) }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let hasMainWindow = NSApp.windows.contains { $0.isVisible && $0.title == "Loom" }
                    if !hasMainWindow { NSApp.setActivationPolicy(.accessory) }
                }
            }
        }
    }

    private func startMenuBarTimer() {
        updateMenuBarTitle()
        accessibilityGranted = Self.testAccessibility()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMenuBarTitle()
                self?.accessibilityGranted = Self.testAccessibility()
            }
        }
    }

    /// Test accessibility by actually trying an AX call instead of relying on the
    /// cached result from AXIsProcessTrusted(). This detects permission changes
    /// without requiring an app relaunch.
    private static func testAccessibility() -> Bool {
        // First quick check
        if AXIsProcessTrusted() { return true }
        // AXIsProcessTrusted can be stale; try an actual AX call as fallback
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let element = AXUIElementCreateApplication(frontApp.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        // If we get success or "no value" (app has no window), we have access.
        // Only .cannotComplete or .notImplemented means no permission.
        return result == .success || result == .noValue || result == .attributeUnsupported
    }

    func setMenuBarIcon(_ icon: MenuBarIcon) {
        _storedMenuBarIcon = icon.label
        menuBarIconName = icon.label
        let isActive = sessionEngine?.isTracking == true && !activityMonitor.isPaused
        menuBarIconSystemName = isActive ? icon.activeIcon : icon.idleIcon
    }

    private func updateMenuBarTitle() {
        let icon = MenuBarIcon.named(menuBarIconName)
        let isActive = sessionEngine?.isTracking == true && !activityMonitor.isPaused
        menuBarIconSystemName = isActive ? icon.activeIcon : icon.idleIcon

        guard showMenuBarText else {
            menuBarTitle = ""

            return
        }
        guard let engine = sessionEngine, engine.isTracking else {
            menuBarTitle = ""

            return
        }
        if activityMonitor.isPaused {
            menuBarTitle = "Paused"

            return
        }
        guard let session = engine.currentSession else {
            menuBarTitle = ""

            return
        }
        let duration = Date().timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        menuBarTitle = "\(hours):\(String(format: "%02d", minutes)) \(session.category)"
    }

    private func createIdleEvent(label: String, duration: TimeInterval) {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-duration)
        let session = Session(
            category: label,
            startTime: startTime,
            endTime: endTime,
            appsUsed: []
        )
        calendarWriter.createEventImmediately(for: session)
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

    private func setAppIcon() {
        // Try loading from the appiconset PNGs first
        if let iconURL = Bundle.module.url(forResource: "icon_512x512@2x", withExtension: "png", subdirectory: "AppIcon.appiconset"),
           let image = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = image
            return
        }
        // Fallback to .icns
        if let icnsURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: icnsURL) {
            NSApp.applicationIconImage = image
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
                setAppIcon()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: appState.menuBarIconSystemName)
                if !appState.menuBarTitle.isEmpty {
                    Text("  \(appState.menuBarTitle)")
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Loom", id: "main") {
            MainWindowView(appState: appState)
                .preferredColorScheme(appearanceScheme)
        }
        .defaultSize(width: 500, height: 700)
    }
}
