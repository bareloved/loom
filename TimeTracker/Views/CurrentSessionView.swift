import SwiftUI

struct CurrentSessionView: View {
    let session: Session
    var onIntentionChanged: ((String?) -> Void)?
    @State private var now = Date()
    @State private var intentionText: String = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 2) {
            // Hero timer
            Text(formattedTime)
                .font(.system(size: 36, weight: .bold, design: .default))
                .monospacedDigit()
                .kerning(-2)
                .foregroundStyle(Theme.textPrimary)

            // Category + app icons
            HStack(spacing: 6) {
                Circle()
                    .fill(CategoryColors.color(for: session.category))
                    .frame(width: 7, height: 7)

                Text(session.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Text("\u{00b7}")
                    .foregroundStyle(Theme.textTertiary)

                // App icons
                ForEach(session.appsUsed.prefix(3), id: \.self) { appName in
                    if let bundleId = appBundleId(for: appName) {
                        Image(nsImage: AppIconCache.shared.icon(forBundleId: bundleId))
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(session.appsUsed.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            // Intention field
            if isEditing {
                TextField("What are you working on?", text: $intentionText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.textPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .onSubmit {
                        commitIntention()
                    }
                    .onExitCommand {
                        isEditing = false
                        intentionText = session.intention ?? ""
                    }
                    .padding(.top, 4)
            } else if let intention = session.intention, !intention.isEmpty {
                Text(intention)
                    .font(.system(size: 12).italic())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .onTapGesture {
                        intentionText = intention
                        isEditing = true
                        isFocused = true
                    }
            } else {
                Text("What are you working on?")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
                    .onTapGesture {
                        intentionText = ""
                        isEditing = true
                        isFocused = true
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { self.now = $0 }
        .onAppear {
            intentionText = session.intention ?? ""
        }
        .onChange(of: session.intention) { _, newValue in
            if !isEditing {
                intentionText = newValue ?? ""
            }
        }
    }

    private func commitIntention() {
        isEditing = false
        let trimmed = intentionText.trimmingCharacters(in: .whitespaces)
        onIntentionChanged?(trimmed.isEmpty ? nil : trimmed)
    }

    private var formattedTime: String {
        let duration = now.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func appBundleId(for appName: String) -> String? {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName })?
            .bundleIdentifier
    }
}
