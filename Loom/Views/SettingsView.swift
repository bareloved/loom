import SwiftUI

struct SettingsView: View {
    @State private var config: CategoryConfig
    @State private var newCategoryName = ""
    @State private var newAppBundleId = ""
    @State private var newRelatedBundleId = ""
    @State private var selectedCategory: String?
    @State private var showingSaveConfirmation = false
    @AppStorage("showMenuBarText") private var showMenuBarText = true
    @AppStorage("goalCategory") private var goalCategory = "Coding"
    @AppStorage("goalHours") private var goalHours = 0.0
    @AppStorage("appearance") private var appearance = "system"

    let onSave: (CategoryConfig) -> Void

    init(config: CategoryConfig, onSave: @escaping (CategoryConfig) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }

    private var sortedCategories: [(String, CategoryRule)] {
        config.categories.sorted { $0.key < $1.key }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            categoriesTab
                .tabItem {
                    Label("Categories", systemImage: "tag")
                }
        }
        .frame(minWidth: 500, minHeight: 350)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show timer in menu bar", isOn: $showMenuBarText)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
            }

            Section("Focus Goal") {
                Picker("Category", selection: $goalCategory) {
                    ForEach(Array(config.categories.keys.sorted()), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                HStack {
                    Text("Daily target")
                    Stepper(
                        value: $goalHours,
                        in: 0...12,
                        step: 0.5
                    ) {
                        Text(goalHours > 0 ? String(format: "%.1fh", goalHours) : "Off")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Categories Tab

    @ViewBuilder
    private var categoriesTab: some View {
        HSplitView {
            // Sidebar: category list
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedCategory) {
                    ForEach(sortedCategories, id: \.0) { name, _ in
                        Text(name)
                            .tag(name)
                    }
                }
                .listStyle(.sidebar)

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
            .frame(minWidth: 160, maxWidth: 200)

            // Detail: selected category
            if let name = selectedCategory, let rule = config.categories[name] {
                VStack(alignment: .leading, spacing: 16) {
                    Text(name)
                        .font(.title2.weight(.semibold))

                    // Primary apps
                    GroupBox("Primary Apps") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(rule.apps, id: \.self) { app in
                                HStack {
                                    Text(app)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button(action: { removeApp(app, from: name) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(spacing: 4) {
                                TextField("Bundle ID (e.g. com.apple.Safari)", text: $newAppBundleId)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { addApp(to: name) }
                                Button("Add") { addApp(to: name) }
                                    .disabled(newAppBundleId.isEmpty)
                            }
                            .padding(.top, 4)
                        }
                        .padding(4)
                    }

                    // Related apps
                    GroupBox("Related Apps") {
                        VStack(alignment: .leading, spacing: 4) {
                            if let related = rule.related, !related.isEmpty {
                                ForEach(related, id: \.self) { app in
                                    HStack {
                                        Text(app)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                        Button(action: { removeRelated(app, from: name) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                Text("None — apps here inherit this category when it's active")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            HStack(spacing: 4) {
                                TextField("Bundle ID", text: $newRelatedBundleId)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { addRelated(to: name) }
                                Button("Add") { addRelated(to: name) }
                                    .disabled(newRelatedBundleId.isEmpty)
                            }
                            .padding(.top, 4)
                        }
                        .padding(4)
                    }

                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack {
                    Spacer()
                    Text("Select a category")
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Reset to Defaults") {
                    if let defaults = try? CategoryConfigLoader.loadDefault() {
                        config = defaults
                    }
                }

                Spacer()

                if showingSaveConfirmation {
                    Text("Saved!")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                Button("Save") {
                    onSave(config)
                    showingSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSaveConfirmation = false
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(.bar)
        }
    }

    // MARK: - Actions

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, config.categories[name] == nil else { return }
        config.categories[name] = CategoryRule(apps: [], related: nil)
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

    private func removeRelated(_ app: String, from category: String) {
        config.categories[category]?.related?.removeAll { $0 == app }
        if config.categories[category]?.related?.isEmpty == true {
            config.categories[category]?.related = nil
        }
    }
}
