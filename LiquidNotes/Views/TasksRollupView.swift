import SwiftUI
import SwiftData

struct TasksRollupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @Query(filter: #Predicate<TaskItem> { $0.note == nil }) private var standaloneTasks: [TaskItem]
    @State private var search = ""
    @State private var showCompleted = true
    @State private var selectedPriority: NotePriority? = nil
    @State private var expandedNotes: Set<UUID> = []
    @State private var editingTaskID: UUID? = nil
    @State private var showingDuePicker = false
    @State private var duePickerTask: TaskItem? = nil
    @State private var showingQuickTaskCapture = false
    @State private var newTaskText = ""
    @State private var newTaskDueDate: Date? = nil
    @State private var showingTaskDuePicker = false
    @State private var toastMessage: String? = nil
    @State private var focusedTaskID: UUID? = nil
    @State private var focusObserver: NSObjectProtocol?
    @State private var recentlyUpdatedTaskID: UUID? = nil
    @State private var showingMoveTaskPicker = false
    @State private var taskToMove: TaskItem? = nil
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LNHeader(title: "Tasks", subtitle: summarySubtitle) { EmptyView() }
                filters
                if filteredNotes.isEmpty && standaloneFiltered.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("No tasks yet")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("Tap + to create your first task")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if !standaloneFiltered.isEmpty {
                                Section {
                                    standaloneSection
                                } header: {
                                    HStack {
                                        Text("Standalone Tasks")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(standaloneFiltered.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, UI.Space.l)
                                    .padding(.top, 8)
                                }
                            }
                            ForEach(filteredNotes, id: \.id) { note in
                                Section {
                                    if isExpanded(note) { taskList(note) }
                                } header: { noteHeader(note) }
                            }
                        }.padding(.horizontal, UI.Space.xl).padding(.top, UI.Space.m)
                        Spacer(minLength: 40)
                    }
                }
            }
            .background(LiquidNotesBackground().ignoresSafeArea())
            .overlay(alignment: .topTrailing) { floatingCreationButton }
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .nativeGlassChip()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showingDuePicker) {
            DueDateCalendarPicker(initialDate: duePickerTask?.dueDate) { selected in
                if let task = duePickerTask {
                    task.dueDate = selected
                    try? modelContext.save()
                    if let note = task.note {
                        if task.dueDate != nil {
                            SharedDataManager.shared.scheduleTaskNotification(for: task, in: note)
                        } else {
                            SharedDataManager.shared.cancelTaskNotification(for: task.id)
                        }
                        updateWidgetData()
                    } else {
                        if task.dueDate != nil {
                            SharedDataManager.shared.scheduleTaskNotification(for: task)
                        } else {
                            SharedDataManager.shared.cancelTaskNotification(for: task.id)
                        }
                        // Widget shows notes; no need to update
                    }
                    BadgeManager.shared.updateBadgeCount()
                    showToast(task.dueDate == nil ? "Due date cleared" : "Due date set")
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQuickTaskCapture) {
            NavigationStack {
                ZStack {
                    LiquidNotesBackground().ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 16) {
                            TextField("Task description", text: $newTaskText, axis: .vertical)
                                .lineLimit(2, reservesSpace: true)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.m)
                                .nativeGlassSurface(cornerRadius: UI.Corner.sPlus)
                            HStack(spacing: 12) {
                                if let d = newTaskDueDate {
                                    Text("Due: \(d.ln_dayDistanceString())")
                                        .font(.caption2)
                                        .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.xs)
                                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                                        .foregroundStyle(.orange)
                                }
                                Button { showingTaskDuePicker = true } label: {
                                    Image(systemName: newTaskDueDate == nil ? "calendar.badge.plus" : "calendar.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(newTaskDueDate == nil ? Color.secondary : Color.orange)
                                        .padding(8)
                                        .nativeGlassCircle()
                                }
                                Spacer()
                            }
                            Spacer(minLength: 0)
                            HStack {
                                Button("Cancel") { showingQuickTaskCapture = false }
                                    .buttonStyle(.borderless)
                                Spacer()
                                Button {
                                    let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    // Create a standalone task (not attached to a note)
                                    let task = TaskItem(text: trimmed, isCompleted: false, note: nil, dueDate: newTaskDueDate)
                                    modelContext.insert(task)
                                    try? modelContext.save()
                                    if task.dueDate != nil {
                                        SharedDataManager.shared.scheduleTaskNotification(for: task)
                                    }
                                    BadgeManager.shared.taskAdded()
                                    HapticManager.shared.success()
                                    showingQuickTaskCapture = false
                                    newTaskText = ""
                                    newTaskDueDate = nil
                                } label: {
                                    Text("Add Task")
                                        .fontWeight(.semibold)
                                    .padding(.horizontal, UI.Space.xl).padding(.vertical, UI.Space.m)
                                        .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .clipShape(Capsule())
                                        .foregroundStyle(.white)
                                }
                                .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .opacity(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                            }
                        }
                        .padding(20)
                    }
                }
                .navigationBarHidden(true)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingTaskDuePicker) {
            DueDateCalendarPicker(initialDate: newTaskDueDate) { selected in newTaskDueDate = selected }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMoveTaskPicker) {
            NavigationStack {
                List {
                    Section("Select a note") {
                        ForEach(allNotes, id: \.id) { note in
                            Button {
                                if let t = taskToMove {
                                    t.note = note
                                    try? modelContext.save()
                                    if t.dueDate != nil { SharedDataManager.shared.scheduleTaskNotification(for: t, in: note) }
                                    BadgeManager.shared.updateBadgeCount()
                                    updateWidgetData()
                                }
                                taskToMove = nil
                                showingMoveTaskPicker = false
                            } label: {
                                HStack {
                                    Text(note.title.isEmpty ? "Untitled" : note.title)
                                    Spacer()
                                    if note.isFavorited { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Move to Note")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingMoveTaskPicker = false; taskToMove = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            focusObserver = NotificationCenter.default.addObserver(forName: .focusTask, object: nil, queue: .main) { notif in
                guard let id = notif.object as? UUID else { return }
                focusedTaskID = id
                if standaloneTasks.contains(where: { $0.id == id }) {
                    // no expansion needed for standalone
                } else {
                    for note in allNotes {
                        if let tasks = note.tasks, tasks.contains(where: { $0.id == id }) {
                            expandedNotes.insert(note.id)
                            break
                        }
                    }
                }
                showToast("Opened Tasks")
            }
        }
        .onDisappear {
            if let obs = focusObserver { NotificationCenter.default.removeObserver(obs) }
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
        // Sort with system notes first (historical behavior), then by priority (custom order), then progress ascending, then modifiedDate desc
        let priorityOrder: [NotePriority:Int] = [.urgent:0, .high:1, .normal:2, .low:3]
        return priorityFiltered.sorted { lhs, rhs in
            // System notes first
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
    @ViewBuilder
    func taskPriorityDot(_ p: NotePriority) -> some View {
        let color: Color = (p == .normal) ? Color.secondary.opacity(0.25) : p.color
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }

    func taskPriorityIcon(_ p: NotePriority) -> some View {
        Image(systemName: p.iconName)
            .font(.caption2)
            .foregroundStyle(p == .normal ? Color.secondary.opacity(0.6) : p.color)
    }

    func updateTaskPriority(_ task: TaskItem, to newPriority: NotePriority, noteContext: Note? = nil) {
        task.priority = newPriority
        try? modelContext.save()
        // Keep the item visible even if filter differs by temporarily whitelisting it
        recentlyUpdatedTaskID = task.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { recentlyUpdatedTaskID = nil }
        // Optionally update widget data if needed (note context available for scheduling)
        if let note = noteContext { SharedDataManager.shared.refreshWidgetData(context: modelContext); _ = note }
    }

    func showToast(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.3)) { toastMessage = nil }
        }
    }
    var summarySubtitle: String {
        let noteCount = filteredNotes.count
        let standaloneCount = standaloneFiltered.count
        return "\(noteCount) notes • \(standaloneCount) standalone"
    }
    
    var standaloneFiltered: [TaskItem] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = standaloneTasks.filter { showCompleted || !$0.isCompleted }
        let searchFiltered: [TaskItem]
        if trimmed.isEmpty {
            searchFiltered = base
        } else {
            searchFiltered = base.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
        }
        let priorityFiltered: [TaskItem]
        if let p = selectedPriority {
            priorityFiltered = searchFiltered.filter { $0.priority == p || $0.id == recentlyUpdatedTaskID }
        } else {
            priorityFiltered = searchFiltered
        }
        // Sort: overdue first, then nearest due, then has due before no due, then priority, then createdDate desc
        let order: [NotePriority:Int] = [.urgent:0, .high:1, .normal:2, .low:3]
        return priorityFiltered.sorted { lhs, rhs in
            let lDue = lhs.dueDate
            let rDue = rhs.dueDate
            let now = Date()
            let lOver = (lDue != nil) && (lDue! < now)
            let rOver = (rDue != nil) && (rDue! < now)
            if lOver != rOver { return lOver && !rOver }
            switch (lDue, rDue) {
            case let (l?, r?):
                if l != r { return l < r }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            let lp = order[lhs.priority, default: 4]
            let rp = order[rhs.priority, default: 4]
            if lp != rp { return lp < rp }
            return lhs.createdDate > rhs.createdDate
        }
    }
    
    var standaloneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(standaloneFiltered, id: \.id) { task in
                HStack(spacing: 10) {
                    Button(action: {
                        task.isCompleted.toggle()
                        try? modelContext.save()
                        BadgeManager.shared.taskCompleted()
                        SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
                    }) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    // Inline priority indicator + icon
                    taskPriorityDot(task.priority)
                    taskPriorityIcon(task.priority)

                    Text(task.text)
                        .strikethrough(task.isCompleted, color: .primary.opacity(0.6))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(3)
                        
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
                            Button(role: .destructive) {
                                task.dueDate = nil
                                SharedDataManager.shared.cancelTaskNotification(for: task.id)
                                try? modelContext.save()
                                SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
                                showToast("Due date cleared")
                            } label: { Label("Clear Date", systemImage: "xmark.circle") }
                        }
                        Button {
                            taskToMove = task
                            showingMoveTaskPicker = true
                        } label: { Label("Move to Note…", systemImage: "arrowshape.turn.up.right") }
                        Divider()
                        Button { updateTaskPriority(task, to: .low) } label: { Label("Priority: Low", systemImage: NotePriority.low.iconName) }
                        Button { updateTaskPriority(task, to: .normal) } label: { Label("Priority: Normal", systemImage: NotePriority.normal.iconName) }
                        Button { updateTaskPriority(task, to: .high) } label: { Label("Priority: High", systemImage: NotePriority.high.iconName) }
                        Button { updateTaskPriority(task, to: .urgent) } label: { Label("Priority: Urgent", systemImage: NotePriority.urgent.iconName) }
                    }
                    Button(role: .destructive) {
                        // Delete standalone task
                        modelContext.delete(task)
                        SharedDataManager.shared.cancelTaskNotification(for: task.id)
                        try? modelContext.save()
                        BadgeManager.shared.updateBadgeCount()
                        SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
                    } label: {
                        Image(systemName: "trash").font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    if task.dueDate != nil {
                        Button(role: .destructive) {
                            task.dueDate = nil
                            SharedDataManager.shared.cancelTaskNotification(for: task.id)
                            try? modelContext.save()
                            showToast("Due date cleared")
                        } label: { Label("Clear Date", systemImage: "xmark.circle") }
                    }
                    Button {
                        taskToMove = task
                        showingMoveTaskPicker = true
                    } label: { Label("Move to Note…", systemImage: "arrowshape.turn.up.right") }
                    Divider()
                    Button { updateTaskPriority(task, to: .low) } label: { Label("Priority: Low", systemImage: NotePriority.low.iconName) }
                    Button { updateTaskPriority(task, to: .normal) } label: { Label("Priority: Normal", systemImage: NotePriority.normal.iconName) }
                    Button { updateTaskPriority(task, to: .high) } label: { Label("Priority: High", systemImage: NotePriority.high.iconName) }
                    Button { updateTaskPriority(task, to: .urgent) } label: { Label("Priority: Urgent", systemImage: NotePriority.urgent.iconName) }
                }
                .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.m)
                        .background(RoundedRectangle(cornerRadius: UI.Corner.sPlus).fill(Color.secondary.opacity(0.08)))
            }
        }
    }
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
            .padding(.horizontal, UI.Space.xl)
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
            .padding(.horizontal, UI.Space.l).padding(.vertical, UI.Space.m)
            .modernGlassCard()
        }.buttonStyle(.plain)
    }
    func taskList(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array((note.tasks ?? []).enumerated()), id: \.element.id) { idx, task in
                if showCompleted || !task.isCompleted {
                    HStack(spacing: 10) {
                        if editingTaskID == task.id {
                            // Editing layout: completion toggle left, then editable text field
                            Button(action: { task.isCompleted.toggle(); note.updateProgress(); try? modelContext.save(); updateWidgetData() }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            // Inline priority indicator + icon
                            taskPriorityDot(task.priority)
                            taskPriorityIcon(task.priority)
                            TextField("Task", text: Binding(
                                get: { task.text },
                                set: { newVal in task.text = newVal; try? modelContext.save(); updateWidgetData() }
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
                                    Button(role: .destructive) {
                                        task.dueDate = nil
                                        SharedDataManager.shared.cancelTaskNotification(for: task.id)
                                        try? modelContext.save()
                                        updateWidgetData()
                                        BadgeManager.shared.updateBadgeCount()
                                        showToast("Due date cleared")
                                    } label: { Label("Clear Date", systemImage: "xmark.circle") }
                                }
                                Button {
                                    // Detach to standalone
                                    task.note = nil
                                    note.updateProgress()
                                    try? modelContext.save()
                                    if task.dueDate != nil { SharedDataManager.shared.scheduleTaskNotification(for: task) }
                                    BadgeManager.shared.updateBadgeCount()
                                    updateWidgetData()
                                    SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
                                    showToast("Detached to Standalone")
                                } label: { Label("Detach to Standalone", systemImage: "arrowshape.turn.up.left") }
                                Divider()
                                Button { updateTaskPriority(task, to: .low) } label: { Label("Priority: Low", systemImage: NotePriority.low.iconName) }
                                Button { updateTaskPriority(task, to: .normal) } label: { Label("Priority: Normal", systemImage: NotePriority.normal.iconName) }
                                Button { updateTaskPriority(task, to: .high) } label: { Label("Priority: High", systemImage: NotePriority.high.iconName) }
                                Button { updateTaskPriority(task, to: .urgent) } label: { Label("Priority: Urgent", systemImage: NotePriority.urgent.iconName) }
                            }
                            Button(role: .destructive, action: { note.removeTask(at: idx); try? modelContext.save(); updateWidgetData() }) { Image(systemName: "trash").font(.caption2) }.buttonStyle(.borderless)
                            // Name edit confirm button (after delete)
                            Button(action: { editingTaskID = nil }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Normal layout: completion toggle at start
                            Button(action: { task.isCompleted.toggle(); note.updateProgress(); try? modelContext.save(); updateWidgetData() }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            // Inline priority indicator + icon
                            taskPriorityDot(task.priority)
                            taskPriorityIcon(task.priority)
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
                                    Button(role: .destructive) {
                                        task.dueDate = nil
                                        SharedDataManager.shared.cancelTaskNotification(for: task.id)
                                        try? modelContext.save()
                                        updateWidgetData()
                                        BadgeManager.shared.updateBadgeCount()
                                        showToast("Due date cleared")
                                    } label: { Label("Clear Date", systemImage: "xmark.circle") }
                                }
                                Button {
                                    // Detach to standalone
                                    task.note = nil
                                    note.updateProgress()
                                    try? modelContext.save()
                                    if task.dueDate != nil { SharedDataManager.shared.scheduleTaskNotification(for: task) }
                                    BadgeManager.shared.updateBadgeCount()
                                    updateWidgetData()
                                    SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
                                    showToast("Detached to Standalone")
                                } label: { Label("Detach to Standalone", systemImage: "arrowshape.turn.up.left") }
                                Divider()
                                Button { task.priority = .low; try? modelContext.save(); showToast("Priority: Low") } label: { Label("Priority: Low", systemImage: NotePriority.low.iconName) }
                                Button { task.priority = .normal; try? modelContext.save(); showToast("Priority: Normal") } label: { Label("Priority: Normal", systemImage: NotePriority.normal.iconName) }
                                Button { task.priority = .high; try? modelContext.save(); showToast("Priority: High") } label: { Label("Priority: High", systemImage: NotePriority.high.iconName) }
                                Button { task.priority = .urgent; try? modelContext.save(); showToast("Priority: Urgent") } label: { Label("Priority: Urgent", systemImage: NotePriority.urgent.iconName) }
                            }
                            Button(role: .destructive, action: { note.removeTask(at: idx); try? modelContext.save(); updateWidgetData() }) { Image(systemName: "trash").font(.caption2) }.buttonStyle(.borderless)
                            if editingTaskID == task.id {
                                // Name edit confirm button (Save capsule)
                                Button(action: { editingTaskID = nil }) {
                                    Text("Save")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .clipShape(Capsule())
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        if editingTaskID != task.id && !task.isCompleted {
                            editingTaskID = task.id
                        }
                    })
                    .contentShape(Rectangle())
                    .contextMenu {
                        if task.dueDate != nil {
                            Button(role: .destructive) {
                                task.dueDate = nil
                                SharedDataManager.shared.cancelTaskNotification(for: task.id)
                                try? modelContext.save()
                                updateWidgetData()
                                BadgeManager.shared.updateBadgeCount()
                            } label: { Label("Clear Date", systemImage: "xmark.circle") }
                        }
                        Button {
                            // Detach to standalone
                            task.note = nil
                            note.updateProgress()
                            try? modelContext.save()
                            if task.dueDate != nil { SharedDataManager.shared.scheduleTaskNotification(for: task) }
                            BadgeManager.shared.updateBadgeCount()
                            updateWidgetData()
                        } label: { Label("Detach to Standalone", systemImage: "arrowshape.turn.up.left") }
                        Divider()
                        Button { updateTaskPriority(task, to: .low) } label: { Label("Priority: Low", systemImage: NotePriority.low.iconName) }
                        Button { updateTaskPriority(task, to: .normal) } label: { Label("Priority: Normal", systemImage: NotePriority.normal.iconName) }
                        Button { updateTaskPriority(task, to: .high) } label: { Label("Priority: High", systemImage: NotePriority.high.iconName) }
                        Button { updateTaskPriority(task, to: .urgent) } label: { Label("Priority: Urgent", systemImage: NotePriority.urgent.iconName) }
                    }
                    .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.m)
                    .background(RoundedRectangle(cornerRadius: UI.Corner.sPlus).fill(Color.secondary.opacity(0.08)))
                }
            }
            Button(action: { note.addTask("New Task"); try? modelContext.save(); updateWidgetData() }) {
                Label("Add Task", systemImage: "plus")
                    .font(.caption)
                    .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.s)
                    .background(Capsule().fill(LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.leading, 6)
        }
        .padding(.horizontal, UI.Space.m).padding(.bottom, UI.Space.m)
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
    
    private var floatingCreationButton: some View {
        Button { 
            showingQuickTaskCapture = true
            HapticManager.shared.buttonTapped()
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
                .frame(width: 56, height: 56)
                .nativeGlassCircle()
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 20)
    }
    
    // (Legacy Quick Tasks note helper removed; standalone tasks are used instead.)
    
    private func updateWidgetData() {
        SharedDataManager.shared.refreshWidgetData(context: modelContext)
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
