import SwiftUI

struct BackfillSheetView: View {
    let date: Date
    let categories: [String]
    let onAdd: (String, Date, Date, String?) -> Void
    let onCancel: () -> Void
    var editingSession: Session? = nil
    var onSave: ((Session) -> Void)? = nil
    var onDelete: ((Session) -> Void)? = nil

    @State private var selectedCategory: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intention: String = ""
    @State private var showDeleteConfirm = false

    private var isEditMode: Bool { editingSession != nil }

    init(
        date: Date,
        categories: [String],
        onAdd: @escaping (String, Date, Date, String?) -> Void,
        onCancel: @escaping () -> Void,
        editingSession: Session? = nil,
        onSave: ((Session) -> Void)? = nil,
        onDelete: ((Session) -> Void)? = nil
    ) {
        self.date = date
        self.categories = categories
        self.onAdd = onAdd
        self.onCancel = onCancel
        self.editingSession = editingSession
        self.onSave = onSave
        self.onDelete = onDelete

        if let session = editingSession {
            self._selectedCategory = State(initialValue: session.category)
            self._startTime = State(initialValue: session.startTime)
            self._endTime = State(initialValue: session.endTime ?? Date())
            self._intention = State(initialValue: session.intention ?? "")
        } else {
            let cal = Calendar.current
            let now = Date()
            let dayStart = cal.startOfDay(for: date)
            let defaultStart = cal.isDate(date, inSameDayAs: now)
                ? now.addingTimeInterval(-3600)
                : dayStart.addingTimeInterval(9 * 3600)
            let defaultEnd = cal.isDate(date, inSameDayAs: now)
                ? now
                : dayStart.addingTimeInterval(10 * 3600)
            self._selectedCategory = State(initialValue: categories.first ?? "Other")
            self._startTime = State(initialValue: defaultStart)
            self._endTime = State(initialValue: defaultEnd)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditMode ? "Edit Session" : "Add Session")
                .font(.headline)

            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                        }
                        .tag(cat)
                    }
                }

                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)

                TextField("Intention (optional)", text: $intention)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if isEditMode {
                    Button("Save Changes") {
                        var updated = editingSession!
                        updated.category = selectedCategory
                        updated.endTime = endTime
                        updated.intention = intention.isEmpty ? nil : intention
                        onSave?(updated)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CategoryColors.accent)
                    .disabled(endTime <= startTime)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Add Session") {
                        onAdd(
                            selectedCategory,
                            startTime,
                            endTime,
                            intention.isEmpty ? nil : intention
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CategoryColors.accent)
                    .disabled(endTime <= startTime)
                    .keyboardShortcut(.defaultAction)
                }
            }

            // Delete section (edit mode only)
            if isEditMode, let session = editingSession {
                Divider()

                if showDeleteConfirm {
                    HStack {
                        Text("Are you sure?")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button("Cancel") { showDeleteConfirm = false }
                            .buttonStyle(.plain)
                        Button("Delete") {
                            onDelete?(session)
                        }
                        .foregroundStyle(.red)
                    }
                } else {
                    Button("Delete Session") {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
