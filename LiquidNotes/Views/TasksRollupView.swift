import SwiftUI
import SwiftData

struct TasksRollupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @State private var search = ""
    @State private var showCompleted = true
    @State private var selectedPriority: NotePriority? = nil
    @State private var expandedNotes: Set<UUID> = []
    @State private var editingTaskID: UUID? = nil
    @State private var showingDuePicker = false
    @State private var duePickerTask: TaskItem? = nil
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LNHeader(title: "Tasks", subtitle: "\(filteredNotes.count) notes") { EmptyView() }
                filters
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredNotes, id: \.id) { note in
                            Section {
                                if isExpanded(note) { taskList(note) }
                            } header: { noteHeader(note) }
                        }
                    }.padding(.horizontal, 18).padding(.top, 12)
                    Spacer(minLength: 40)
                }
            }
            .background(LiquidNotesBackground().ignoresSafeArea())
        }
        .sheet(isPresented: $showingDuePicker) {
            DueDateCalendarPicker(initialDate: duePickerTask?.dueDate) { selected in
                if let task = duePickerTask { task.dueDate = selected; try? modelContext.save() }
            }
            .presentationDetents([.medium])
        }
    }
    private var filteredNotes: [Note] {
        // Break chained operations into clear steps to aid compiler type-checking
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let withTasks = allNotes.filter { note in
            guard let tasks = note.tasks else { return false }
            return !tasks.isEmpty
        }
        let searchFiltered: [Note]
        if trimmed.isEmpty {
            searchFiltered = withTasks
        } else {
            searchFiltered = withTasks.filter { note in
                if note.title.localizedCaseInsensitiveContains(trimmed) { return true }
                if let tasks = note.tasks, tasks.contains(where: { $0.text.localizedCaseInsensitiveContains(trimmed) }) { return true }
                return false
            }
        }
        let priorityFiltered: [Note]
        if let p = selectedPriority {
            priorityFiltered = searchFiltered.filter { $0.priority == p }
        } else {
            priorityFiltered = searchFiltered
        }
        // Sort with Quick Tasks (system notes) always first, then by priority (custom order), then progress ascending, then modifiedDate desc
        let priorityOrder: [NotePriority:Int] = [.urgent:0, .high:1, .normal:2, .low:3]
        return priorityFiltered.sorted { lhs, rhs in
            // Quick Tasks (system) first
            if lhs.isSystem != rhs.isSystem { return lhs.isSystem && !rhs.isSystem }
            let lp = priorityOrder[lhs.priority, default: 4]
            let rp = priorityOrder[rhs.priority, default: 4]
            if lp != rp { return lp < rp }
            if lhs.progress != rhs.progress { return lhs.progress < rhs.progress }
            return lhs.modifiedDate > rhs.modifiedDate
        }
    }
}

private extension TasksRollupView {
    var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ToggleFilterChip(label: showCompleted ? "Hide Completed" : "Show Completed", isActive: !showCompleted) { withAnimation { showCompleted.toggle() } }
                ForEach([nil] + NotePriority.allCases, id: \.self) { pri in
                    let label = pri == nil ? "All Priorities" : pri!.rawValue.capitalized
                    let active = selectedPriority == pri
                    ToggleFilterChip(label: label, isActive: active) {
                        withAnimation { selectedPriority = active ? nil : pri }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
    }
    func isExpanded(_ note: Note) -> Bool { expandedNotes.contains(note.id) }
    func toggleExpanded(_ note: Note) { if expandedNotes.contains(note.id) { expandedNotes.remove(note.id) } else { expandedNotes.insert(note.id) } }
    func noteHeader(_ note: Note) -> some View {
        Button(action: { withAnimation(.bouncy(duration: 0.35)) { toggleExpanded(note) } }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline).lineLimit(1)
                        if note.isFavorited { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                    }
                    HStack(spacing: 10) {
                        priorityBadge(note.priority)
                        progressBadge(note)
                        if let due = note.dueDate { Text(due.ln_dayDistanceString()).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Color.orange.opacity(0.15))).foregroundStyle(.orange) }
                    }
                }
                Spacer()
                Image(systemName: isExpanded(note) ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
    func taskList(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array((note.tasks ?? []).enumerated()), id: \.element.id) { idx, task in
                if showCompleted || !task.isCompleted {
                    HStack(spacing: 10) {
                        if editingTaskID == task.id {
                            // Editing layout: completion toggle left, then editable text field
                            Button(action: { task.isCompleted.toggle(); note.updateProgress(); try? modelContext.save() }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Task", text: Binding(
                                get: { task.text },
                                set: { newVal in task.text = newVal; try? modelContext.save() }
                            ))
                            .textFieldStyle(.plain)
                            .disabled(task.isCompleted)
                            .onSubmit { editingTaskID = nil }
                            .onDisappear { editingTaskID = editingTaskID == task.id ? nil : editingTaskID }
                            if let due = task.dueDate {
                                let isOverdue = !task.isCompleted && Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
                                Text(due.ln_dayDistanceString())
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill((isOverdue ? Color.red : Color.orange).opacity(0.18)))
                                    .foregroundStyle(isOverdue ? .red : .orange)
                            }
                            Spacer(minLength: 4)
                            Button {
                                duePickerTask = task
                                showingDuePicker = true
                            } label: {
                                Image(systemName: task.dueDate == nil ? "calendar" : "calendar.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(task.dueDate == nil ? Color.secondary : Color.orange)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if task.dueDate != nil {
                                    Button(role: .destructive) { task.dueDate = nil; try? modelContext.save() } label: { Label("Clear Date", systemImage: "xmark.circle") }
                                }
                            }
                            Button(role: .destructive, action: { note.removeTask(at: idx); try? modelContext.save() }) { Image(systemName: "trash").font(.caption2) }.buttonStyle(.borderless)
                            // Name edit confirm button (after delete)
                            Button(action: { editingTaskID = nil }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Normal layout: completion toggle at start
                            Button(action: { task.isCompleted.toggle(); note.updateProgress(); try? modelContext.save() }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            if editingTaskID == task.id {
                                EmptyView()
                            }
                            if editingTaskID != task.id {
                                Text(task.text)
                                    .strikethrough(task.isCompleted, color: .primary.opacity(0.6))
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                    .lineLimit(3)
                                    .onTapGesture { if !task.isCompleted { editingTaskID = task.id } }
                            }
                            if let due = task.dueDate {
                                let isOverdue = !task.isCompleted && Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
                                Text(due.ln_dayDistanceString())
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Capsule().fill((isOverdue ? Color.red : Color.orange).opacity(0.18)))
                                    .foregroundStyle(isOverdue ? .red : .orange)
                            }
                            Spacer()
                            Button {
                                duePickerTask = task
                                showingDuePicker = true
                            } label: {
                                Image(systemName: task.dueDate == nil ? "calendar" : "calendar.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(task.dueDate == nil ? Color.secondary : Color.orange)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if task.dueDate != nil {
                                    Button(role: .destructive) { task.dueDate = nil; try? modelContext.save() } label: { Label("Clear Date", systemImage: "xmark.circle") }
                                }
                            }
                            Button(role: .destructive, action: { note.removeTask(at: idx); try? modelContext.save() }) { Image(systemName: "trash").font(.caption2) }.buttonStyle(.borderless)
                            if editingTaskID == task.id {
                                // Name edit confirm button (placed after delete)
                                Button(action: { editingTaskID = nil }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08)))
                }
            }
            Button(action: { note.addTask("New Task"); try? modelContext.save() }) {
                Label("Add Task", systemImage: "plus")
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Capsule().fill(LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 10).padding(.bottom, 14)
    }
    func priorityBadge(_ p: NotePriority) -> some View {
        HStack(spacing: 4) {
            Image(systemName: p.iconName).font(.caption2)
            Text(p.rawValue.capitalized).font(.caption2)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(p.color.opacity(0.25)))
        .foregroundStyle(p.color == .clear ? .secondary : p.color)
    }
    func progressBadge(_ note: Note) -> some View {
        HStack(spacing: 4) {
            Image(systemName: note.progress >= 1 ? "checkmark.circle.fill" : "clock").font(.caption2)
            Text("\(Int(note.progress * 100))%")
                .font(.caption2)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(note.progress >= 1 ? Color.green.opacity(0.25) : Color.secondary.opacity(0.15)))
        .foregroundStyle(note.progress >= 1 ? .green : .secondary)
    }
}

private struct ToggleFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(isActive ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12)))
            .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.6))
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .onTapGesture { action() }
    }
}

#Preview {
    TasksRollupView().modelContainer(for: [Note.self, Folder.self])
}