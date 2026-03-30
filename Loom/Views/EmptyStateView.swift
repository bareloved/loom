import SwiftUI

struct EmptyStateView: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.textQuaternary)
                    .padding(.bottom, 4)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
