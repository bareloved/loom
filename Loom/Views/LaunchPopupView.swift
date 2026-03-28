import SwiftUI

struct LaunchPopupView: View {
    let categories: [String]
    let onStart: (String, String?) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategory: String
    @State private var intention = ""

    init(categories: [String], onStart: @escaping (String, String?) -> Void, onDismiss: @escaping () -> Void) {
        self.categories = categories
        self.onStart = onStart
        self.onDismiss = onDismiss
        self._selectedCategory = State(initialValue: categories.first ?? "Other")
    }

    var body: some View {
        VStack(spacing: 14) {
            SunriseAnimation()
                .padding(.top, 4)

            Text("Ready to focus?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            // Category picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(CategoryColors.color(for: category))
                                    .frame(width: 6, height: 6)
                                Text(category)
                                    .font(.system(size: 11, weight: selectedCategory == category ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(selectedCategory == category ? CategoryColors.color(for: category).opacity(0.15) : Theme.trackFill)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedCategory == category ? CategoryColors.color(for: category).opacity(0.4) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Intention field
            TextField("What are you working on? (optional)", text: $intention)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .onSubmit { startSession() }

            Button(action: startSession) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button("Not now") {
                onDismiss()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: 320)
    }

    private func startSession() {
        onStart(selectedCategory, intention.isEmpty ? nil : intention)
    }
}
