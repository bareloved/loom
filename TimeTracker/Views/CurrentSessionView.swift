import SwiftUI

struct CurrentSessionView: View {
    let session: Session
    @State private var now = Date()

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
                    .fill(Color(hex: 0x5a9a6e))
                    .frame(width: 7, height: 7)

                Text(session.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Text("·")
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
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { self.now = $0 }
    }

    private var formattedTime: String {
        let duration = now.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    // Look up bundleId from the ActivityMonitor's latest records
    // For now, use NSWorkspace to find running apps by name
    private func appBundleId(for appName: String) -> String? {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName })?
            .bundleIdentifier
    }
}
