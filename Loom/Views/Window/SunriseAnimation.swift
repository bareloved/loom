import SwiftUI

struct SunriseAnimation: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Outer glow (bottom layer)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [CategoryColors.accent.opacity(0.25), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 70)
                .offset(y: -5)
                .opacity(animate ? 1 : 0)

            // Half circle (sun) — clipped to top half, rises from below horizon
            VStack(spacing: 0) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xe8955a), CategoryColors.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56, height: 56)
                Spacer().frame(height: 0)
            }
            .frame(width: 56, height: 28, alignment: .top)
            .clipped()
            .offset(y: animate ? 2 : 18)
            .opacity(animate ? 1 : 0.2)

            // Horizon line (TOP layer — in front of sun)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, CategoryColors.accent, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: animate ? 90 : 0, height: 2)
                .offset(y: 16)
                .zIndex(1)
        }
        .frame(width: 120, height: 70)
        .onAppear {
            withAnimation(.easeOut(duration: 2)) {
                animate = true
            }
        }
    }
}
