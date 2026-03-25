import SwiftUI
import LoomKit

struct SettingsTabView: View {
    let appState: MobileAppState

    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationView {
            List {
                // MARK: - Categories
                Section("Categories") {
                    if let config = appState.categoryConfig {
                        ForEach(config.orderedCategoryNames, id: \.self) { name in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(CategoryColors.color(for: name))
                                    .frame(width: 10, height: 10)
                                Text(name)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    } else {
                        Text("No categories loaded")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
        }
        .background(Theme.background)
    }
}
