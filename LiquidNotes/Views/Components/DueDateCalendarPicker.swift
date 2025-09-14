import SwiftUI

struct DueDateCalendarPicker: View {
    @Environment(\.dismiss) private var dismiss
    let initialDate: Date?
    let onSelect: (Date?) -> Void
    @State private var tempDate: Date = Date()
    @State private var includeTime: Bool = false
    init(initialDate: Date?, onSelect: @escaping (Date?) -> Void) {
        self.initialDate = initialDate
        self.onSelect = onSelect
        _tempDate = State(initialValue: initialDate ?? Date())
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    "Due Date",
                    selection: $tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 12)
                quickChips
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
            .background(LiquidNotesBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if initialDate != nil {
                        Button("Clear", role: .destructive) { onSelect(nil); dismiss() }
                    }
                    Button("Set") { onSelect(tempDate); dismiss() }
                        .disabled(!isChanged)
                }
            }
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private var isChanged: Bool { initialDate == nil || !Calendar.current.isDate(initialDate!, inSameDayAs: tempDate) }
    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickChip("Today") { tempDate = Date() }
                quickChip("Tomorrow") { tempDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }
                quickChip("In 3 Days") { tempDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date() }
                quickChip("Next Week") { tempDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date() }
                quickChip("Next Month") { tempDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date() }
            }
            .padding(.horizontal, UI.Space.l)
            .padding(.vertical, 4)
        }
    }
    private func quickChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.xs)
                .nativeGlassChip()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DueDateCalendarPicker(initialDate: nil) { _ in }
}
