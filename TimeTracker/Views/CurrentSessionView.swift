import SwiftUI

struct CurrentSessionView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Session")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(session.category)
                .font(.headline)

            Text("\(session.appsUsed.joined(separator: ", ")) — \(formattedDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var formattedDuration: String {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
