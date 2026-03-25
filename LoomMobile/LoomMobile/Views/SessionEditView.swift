import SwiftUI
import LoomKit

struct SessionEditView: View {
    let session: Session
    let categories: [String]
    let onSave: (Session) -> Void
    let onCancel: () -> Void

    @State private var selectedCategory: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intention: String

    init(session: Session, categories: [String], onSave: @escaping (Session) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.categories = categories
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedCategory = State(initialValue: session.category)
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime ?? Date())
        _intention = State(initialValue: session.intention ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }

                LabeledContent("Start") {
                    Text(startTime.formatted(date: .abbreviated, time: .shortened))
                }
                DatePicker("End", selection: $endTime)

                TextField("Intention", text: $intention)
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = session
                        updated.category = selectedCategory
                        updated.endTime = endTime
                        if intention.isEmpty {
                            updated.intention = nil
                        } else {
                            updated.intention = intention
                        }
                        onSave(updated)
                    }
                }
            }
        }
    }
}
