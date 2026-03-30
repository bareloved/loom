import SwiftUI

struct ToastOverlayView: View {
    let toastManager: ToastManager

    var body: some View {
        VStack(spacing: 6) {
            ForEach(toastManager.visibleToasts) { toast in
                ToastBanner(toast: toast, onDismiss: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        toastManager.dismiss(toast.id)
                    }
                })
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.25), value: toastManager.visibleToasts.map(\.id))
    }
}

private struct ToastBanner: View {
    let toast: Toast
    let onDismiss: () -> Void

    private var backgroundColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.18, green: 0.29, blue: 0.18)
        case .info: return Color(red: 0.18, green: 0.23, blue: 0.29)
        case .warning: return Color(red: 0.29, green: 0.23, blue: 0.18)
        case .error: return Color(red: 0.29, green: 0.18, blue: 0.18)
        }
    }

    private var borderColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.24, green: 0.42, blue: 0.24)
        case .info: return Color(red: 0.24, green: 0.35, blue: 0.49)
        case .warning: return Color(red: 0.49, green: 0.35, blue: 0.24)
        case .error: return Color(red: 0.49, green: 0.24, blue: 0.24)
        }
    }

    private var textColor: Color {
        switch toast.type {
        case .success: return Color(red: 0.78, green: 0.90, blue: 0.79)
        case .info: return Color(red: 0.73, green: 0.87, blue: 0.98)
        case .warning: return Color(red: 1.0, green: 0.88, blue: 0.70)
        case .error: return Color(red: 1.0, green: 0.80, blue: 0.82)
        }
    }

    private var iconName: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(textColor)

            Text(toast.message)
                .font(.system(size: 12))
                .foregroundStyle(textColor)

            Spacer()

            if let action = toast.action, let label = toast.actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(textColor)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            if toast.type == .warning || toast.type == .error {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
