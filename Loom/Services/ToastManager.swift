import Foundation
import SwiftUI

enum ToastType {
    case success
    case info
    case warning
    case error
}

struct Toast: Identifiable {
    let id = UUID()
    let type: ToastType
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?
}

@Observable
@MainActor
final class ToastManager {
    private(set) var visibleToasts: [Toast] = []
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    func show(_ type: ToastType, message: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        let toast = Toast(type: type, message: message, action: action, actionLabel: actionLabel)

        // Max 2 visible — remove oldest if at limit
        if visibleToasts.count >= 2 {
            let oldest = visibleToasts[0]
            dismiss(oldest.id)
        }

        visibleToasts.append(toast)

        // Auto-dismiss success and info after 3 seconds
        if type == .success || type == .info {
            let toastId = toast.id
            dismissTasks[toastId] = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                dismiss(toastId)
            }
        }
    }

    func dismiss(_ id: UUID) {
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
        visibleToasts.removeAll { $0.id == id }
    }
}
