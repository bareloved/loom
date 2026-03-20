import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case focusGuard = "Focus Guard"
    case notification = "Notification"
    case calendar = "Calendar"
    case category = "Category"
    case window = "Window"
    case browser = "Browser Tracking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .focusGuard: return "eye.trianglebadge.exclamationmark"
        case .notification: return "bell"
        case .calendar: return "calendar"
        case .category: return "tag"
        case .window: return "macwindow"
        case .browser: return "globe"
        }
    }
}

struct SettingsTabView: View {
    @State private var config: CategoryConfig
    @State private var selectedSection: SettingsSection = .general
    @State private var selectedCategory: String?
    @State private var newCategoryName = ""
    @State private var newAppBundleId = ""
    @State private var newRelatedBundleId = ""
    @State private var newUrlPattern = ""
    @State private var editingCalendarName = ""
    @State private var showingIconPicker = false

    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("showMenuBarText") private var showMenuBarText = true
    @AppStorage("goalCategory") private var goalCategory = "Coding"
    @AppStorage("goalHours") private var goalHours = 0.0
    @AppStorage("focusGuardEnabled") private var focusGuardEnabled = true
    @AppStorage("focusThreshold") private var focusThreshold: Double = 30
    @AppStorage("snoozeDuration") private var snoozeDuration: Double = 300

    let calendarWriter: CalendarWriter
    let appState: AppState
    let onSave: (CategoryConfig) -> Void

    init(config: CategoryConfig, calendarWriter: CalendarWriter, appState: AppState, onSave: @escaping (CategoryConfig) -> Void) {
        self._config = State(initialValue: config)
        self.calendarWriter = calendarWriter
        self.appState = appState
        self.onSave = onSave
    }

    private var sortedCategories: [(String, CategoryRule)] {
        config.categories.sorted { $0.key < $1.key }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    Button(action: { selectedSection = section }) {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            Text(section.rawValue)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(selectedSection == section ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .background(
                            selectedSection == section
                                ? CategoryColors.accent
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 170)
            .background(Theme.backgroundSecondary)

            // Divider
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)

            // Detail
            VStack(spacing: 0) {
                if selectedSection == .category {
                    VStack(alignment: .leading, spacing: 16) {
                        categorySection
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedSection {
                            case .general:
                                generalSection
                            case .focusGuard:
                                focusGuardSection
                            case .notification:
                                placeholderSection("Notification settings coming soon.")
                            case .calendar:
                                calendarSection
                            case .window:
                                windowSection
                            case .browser:
                                placeholderSection("Browser tracking settings coming soon.")
                            default:
                                EmptyView()
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

            }
        }
        .onChange(of: config) { _, newConfig in
            onSave(newConfig)
        }
    }

    // MARK: - Settings Card

    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        Text("General")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)

        settingsCard("Appearance") {
            HStack {
                Text("Theme")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("", selection: $appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
            }
        }

        settingsCard("Menu Bar") {
            VStack(spacing: 10) {
                HStack {
                    Text("Show timer text")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $showMenuBarText)
                        .toggleStyle(.switch)
                        .tint(CategoryColors.accent)
                        .labelsHidden()
                }

                Divider()

                HStack {
                    Text("Icon")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        showingIconPicker.toggle()
                    } label: {
                        let selected = MenuBarIcon.named(appState.menuBarIconName)
                        HStack(spacing: 7) {
                            Image(systemName: selected.activeIcon)
                                .font(.system(size: 15))
                            Text(selected.label)
                                .font(.system(size: 14))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(MenuBarIcon.allGroups) { group in
                                    Text(group.name.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, group.id == MenuBarIcon.allGroups.first?.id ? 4 : 10)
                                        .padding(.bottom, 2)

                                    ForEach(group.icons) { icon in
                                        Button {
                                            appState.setMenuBarIcon(icon)
                                            showingIconPicker = false
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: icon.activeIcon)
                                                    .font(.system(size: 16))
                                                    .frame(width: 24)
                                                Text(icon.label)
                                                    .font(.system(size: 14))
                                                Spacer()
                                                if appState.menuBarIconName == icon.label {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(CategoryColors.accent)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .background(
                                            appState.menuBarIconName == icon.label
                                                ? CategoryColors.accent.opacity(0.1)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 5)
                                        )
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(width: 200, height: 380)
                    }
                }
            }
        }

        settingsCard("Focus Goal") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Category")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: $goalCategory) {
                        ForEach(Array(config.categories.keys.sorted()), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .frame(width: 140)
                }

                Divider()

                HStack {
                    Text("Daily target")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(goalHours > 0 ? String(format: "%.1fh", goalHours) : "Off")
                        .foregroundStyle(Theme.textSecondary)
                    Stepper("", value: $goalHours, in: 0...12, step: 0.5)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Focus Guard

    @ViewBuilder
    private var focusGuardSection: some View {
        Text("Focus Guard")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)

        settingsCard("Focus Guard") {
            VStack(spacing: 10) {
                HStack {
                    Text("Enabled")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $focusGuardEnabled)
                        .toggleStyle(.switch)
                        .tint(CategoryColors.accent)
                        .labelsHidden()
                }

                if focusGuardEnabled {
                    Divider()

                    HStack {
                        Text("Distraction threshold")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(focusThreshold))s")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: $focusThreshold, in: 15...120, step: 5)
                            .frame(width: 140)
                            .tint(CategoryColors.accent)
                    }

                    Divider()

                    HStack {
                        Text("Snooze duration")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Picker("", selection: $snoozeDuration) {
                            Text("2 min").tag(120.0)
                            Text("5 min").tag(300.0)
                            Text("10 min").tag(600.0)
                            Text("20 min").tag(1200.0)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 240)
                    }
                }
            }
        }
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarSection: some View {
        Text("Calendar")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)

        settingsCard("Calendar Sync") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Write sessions to calendar")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { calendarWriter.writeEnabled },
                        set: { calendarWriter.writeEnabled = $0 }
                    ))
                        .toggleStyle(.switch)
                        .tint(CategoryColors.accent)
                        .labelsHidden()
                }

                if calendarWriter.writeEnabled {
                    Divider()

                    HStack {
                        Text("Calendar name")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        TextField("", text: $editingCalendarName)
                            .textFieldStyle(.plain)
                            .frame(width: 140)
                            .padding(6)
                            .background(Theme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit {
                                if !editingCalendarName.isEmpty {
                                    calendarWriter.renameCalendar(to: editingCalendarName)
                                }
                            }
                    }

                    Divider()

                    HStack {
                        Text("Account")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { calendarWriter.currentSourceTitle },
                            set: { newTitle in
                                calendarWriter.switchSource(to: newTitle)
                            }
                        )) {
                            ForEach(calendarWriter.availableSources, id: \.sourceIdentifier) { source in
                                Text(source.title).tag(source.title)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }
        }
        .onAppear {
            editingCalendarName = calendarWriter.calendarName
        }

        settingsCard("Time Rounding") {
            HStack {
                Text("Round time blocks to")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("", selection: Binding(
                    get: { calendarWriter.timeRounding },
                    set: { calendarWriter.timeRounding = $0 }
                )) {
                    Text("None").tag(0)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }

        if calendarWriter.isAuthorized {
            settingsCard("Status") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Calendar access granted")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        } else {
            settingsCard("Status") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CategoryColors.accent)
                        .frame(width: 8, height: 8)
                    Text("Calendar access not granted")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    // MARK: - Category

    @ViewBuilder
    private var categorySection: some View {
        Text("Categories")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)

        HSplitView {
            // Category list
            VStack(alignment: .leading, spacing: 2) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(sortedCategories, id: \.0) { name, _ in
                            Button(action: { selectedCategory = name }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(CategoryColors.color(for: name))
                                        .frame(width: 8, height: 8)
                                    Text(name)
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(selectedCategory == name ? .white : Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                                .background(
                                    selectedCategory == name
                                        ? AnyShapeStyle(CategoryColors.accent)
                                        : AnyShapeStyle(.clear),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }

                Divider()

                HStack(spacing: 4) {
                    TextField("New category", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addCategory() }
                    Button(action: addCategory) {
                        Image(systemName: "plus")
                    }
                    .disabled(newCategoryName.isEmpty)
                    Button(action: removeSelectedCategory) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedCategory == nil)
                }
                .padding(8)
            }
            .frame(minWidth: 140, maxWidth: 180)
            .background(Theme.backgroundSecondary)

            // Category detail
            if let name = selectedCategory, let rule = config.categories[name] {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(name)
                            .font(.headline)

                        settingsCard("Primary Apps") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(rule.apps, id: \.self) { bundleId in
                                    appRow(bundleId: bundleId) {
                                        removeApp(bundleId, from: name)
                                    }
                                }
                                Button(action: { pickApp { bundleId in addApp(to: name, bundleId: bundleId) } }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                        Text("Add app")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(CategoryColors.accent)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }

                        settingsCard("Related Apps") {
                            VStack(alignment: .leading, spacing: 6) {
                                if let related = rule.related, !related.isEmpty {
                                    ForEach(related, id: \.self) { bundleId in
                                        appRow(bundleId: bundleId) {
                                            removeRelated(bundleId, from: name)
                                        }
                                    }
                                } else {
                                    Text("None")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Button(action: { pickApp { bundleId in addRelated(to: name, bundleId: bundleId) } }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                        Text("Add app")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(CategoryColors.accent)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }

                        settingsCard("URL Patterns") {
                            VStack(alignment: .leading, spacing: 4) {
                                if let patterns = rule.urlPatterns, !patterns.isEmpty {
                                    ForEach(patterns, id: \.self) { pattern in
                                        HStack {
                                            Text(pattern)
                                                .font(.system(.body, design: .monospaced))
                                            Spacer()
                                            Button(action: { removeUrlPattern(pattern, from: name) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(Theme.textTertiary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    Text("None")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                HStack(spacing: 4) {
                                    TextField("URL pattern", text: $newUrlPattern)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { addUrlPattern(to: name) }
                                    Button("Add") { addUrlPattern(to: name) }
                                        .disabled(newUrlPattern.isEmpty)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a category")
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: 400, maxHeight: .infinity)
    }

    // MARK: - Window

    @ViewBuilder
    private var windowSection: some View {
        Text("Window")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)

        settingsCard("Startup") {
            Toggle("Launch at login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to toggle launch at login: \(error)")
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(CategoryColors.accent)
        }
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholderSection(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - App Row

    @ViewBuilder
    private func appRow(bundleId: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconCache.shared.icon(forBundleId: bundleId))
                .resizable()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(AppIconCache.shared.displayName(forBundleId: bundleId) ?? bundleId)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var installedAppOptions: [(name: String, bundleId: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (name: name, bundleId: bundleId)
            }
            .sorted { $0.name < $1.name }
    }

    // MARK: - App Picker

    private func pickApp(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                completion(bundleId)
            }
        }
    }

    // MARK: - Actions

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, config.categories[name] == nil else { return }
        config.categories[name] = CategoryRule(apps: [], related: nil, urlPatterns: nil)
        selectedCategory = name
        newCategoryName = ""
    }

    private func removeSelectedCategory() {
        guard let name = selectedCategory else { return }
        config.categories.removeValue(forKey: name)
        selectedCategory = sortedCategories.first?.0
    }

    private func addApp(to category: String) {
        let bundleId = newAppBundleId.trimmingCharacters(in: .whitespaces)
        guard !bundleId.isEmpty else { return }
        config.categories[category]?.apps.append(bundleId)
        newAppBundleId = ""
    }

    private func addApp(to category: String, bundleId: String) {
        guard !bundleId.isEmpty,
              !(config.categories[category]?.apps.contains(bundleId) ?? false) else { return }
        config.categories[category]?.apps.append(bundleId)
    }

    private func removeApp(_ app: String, from category: String) {
        config.categories[category]?.apps.removeAll { $0 == app }
    }

    private func addRelated(to category: String) {
        let bundleId = newRelatedBundleId.trimmingCharacters(in: .whitespaces)
        guard !bundleId.isEmpty else { return }
        if config.categories[category]?.related == nil {
            config.categories[category]?.related = []
        }
        config.categories[category]?.related?.append(bundleId)
        newRelatedBundleId = ""
    }

    private func addRelated(to category: String, bundleId: String) {
        guard !bundleId.isEmpty else { return }
        if config.categories[category]?.related == nil {
            config.categories[category]?.related = []
        }
        if !(config.categories[category]?.related?.contains(bundleId) ?? false) {
            config.categories[category]?.related?.append(bundleId)
        }
    }

    private func removeRelated(_ app: String, from category: String) {
        config.categories[category]?.related?.removeAll { $0 == app }
        if config.categories[category]?.related?.isEmpty == true {
            config.categories[category]?.related = nil
        }
    }

    private func addUrlPattern(to category: String) {
        let pattern = newUrlPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        if config.categories[category]?.urlPatterns == nil {
            config.categories[category]?.urlPatterns = []
        }
        config.categories[category]?.urlPatterns?.append(pattern)
        newUrlPattern = ""
    }

    private func removeUrlPattern(_ pattern: String, from category: String) {
        config.categories[category]?.urlPatterns?.removeAll { $0 == pattern }
        if config.categories[category]?.urlPatterns?.isEmpty == true {
            config.categories[category]?.urlPatterns = nil
        }
    }
}
