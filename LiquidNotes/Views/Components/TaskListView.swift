import SwiftUI

struct TaskListView: View {
    @Binding var tasks: [TaskItem]
    let onToggle: (Int) -> Void
    let onDelete: (Int) -> Void
    let onAdd: (String, Date?) -> Void
    
    @State private var newTaskText = ""
    @State private var isAddingTask = false
    @State private var newTaskDueDate: Date? = nil
    @State private var showingCalendar = false // calendar for new task creation (future use if switching from Menu)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tasks", systemImage: "checklist")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if !tasks.isEmpty {
                    ProgressCircle(progress: calculateProgress())
                }
                
                Button(action: {
                    withAnimation(.bouncy(duration: 0.3)) {
                        isAddingTask.toggle()
                    }
                }) {
                    Image(systemName: isAddingTask ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if isAddingTask {
                HStack(spacing: 12) {
                    TextField("New task...", text: $newTaskText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .modernGlassCard()
                        .onSubmit {
                            addNewTask()
                        }
                    Menu {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { newTaskDueDate ?? Date() },
                                set: { newVal in newTaskDueDate = newVal }
                            ),
                            displayedComponents: .date
                        )
                        if newTaskDueDate != nil {
                            Button(role: .destructive) { newTaskDueDate = nil } label: { Label("Clear Date", systemImage: "xmark.circle") }
                        }
                    } label: {
                        Image(systemName: newTaskDueDate == nil ? "calendar.badge.plus" : "calendar")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Button(action: addNewTask) {
                        Text("Add")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(newTaskText.isEmpty)
                }
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    let sorted = tasks.enumerated().sorted { lhs, rhs in
                        let l = lhs.element
                        let r = rhs.element
                        switch (l.dueDate, r.dueDate) {
                        case let (ld?, rd?): if ld != rd { return ld < rd }
                        case (_?, nil): return true
                        case (nil, _?): return false
                        default: break
                        }
                        if l.isCompleted != r.isCompleted { return !l.isCompleted && r.isCompleted }
                        return l.createdDate < r.createdDate
                    }
                    ForEach(Array(sorted.indices), id: \.self) { i in
                        let pair = sorted[i]
                        let index = pair.offset
                        let task = pair.element
                        TaskRowView(
                            task: task,
                            onToggle: { withAnimation(.bouncy(duration: 0.3)) { onToggle(index) } },
                            onDelete: { withAnimation(.bouncy(duration: 0.4)) { onDelete(index) } }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 300)
        }
        .background(.clear)
        .ambientGlassEffect()
    }
    
    private func calculateProgress() -> Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
    
    private func addNewTask() {
        guard !newTaskText.isEmpty else { return }
        onAdd(newTaskText, newTaskDueDate)
        newTaskText = ""
        newTaskDueDate = nil
        withAnimation(.bouncy(duration: 0.3)) {
            isAddingTask = false
        }
        HapticManager.shared.buttonTapped()
    }
}

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showingCalendar = false

    private var isOverdue: Bool {
        if let due = task.dueDate {
            return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date()) && !task.isCompleted
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        task.isCompleted ?
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.gray, .gray.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: task.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.text)
                    .foregroundStyle(.primary)
                    .strikethrough(task.isCompleted, color: .primary.opacity(0.5))
                if let due = task.dueDate {
                    Text(Calendar.current.isDateInToday(due) ? "Today" : due.formatted(.relative(presentation: .numeric)))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(isOverdue ? Color.red.opacity(0.18) : Color.orange.opacity(0.10))
                        )
                        .foregroundStyle(isOverdue ? Color.red : Color.orange)
                        .accessibilityLabel(isOverdue ? "Task overdue" : "Due date")
                }
            }
            Spacer()
            Button { showingCalendar = true } label: {
                Image(systemName: task.dueDate == nil ? "calendar" : "calendar.circle.fill")
                    .font(.callout)
                    .foregroundStyle(task.dueDate == nil ? Color.secondary : Color.orange)
            }
            .buttonStyle(.plain)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .background(
                    task.isCompleted ?
                    AnyView(Color.green.opacity(0.05)) :
                    AnyView(Color.clear)
                )
        )
        .modernGlassCard()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering }
        }
        .onTapGesture { onToggle() }
        .sheet(isPresented: $showingCalendar) {
            DueDateCalendarPicker(initialDate: task.dueDate) { selected in
                task.dueDate = selected
                showingCalendar = false
            }
            .presentationDetents([.medium])
        }
    }
}

struct ProgressCircle: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(colors: [
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.06)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2
                )
                .blendMode(.plusLighter)
                .opacity(0.85)
                .frame(width: 28, height: 28)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(-90))
                .animation(.bouncy(duration: 0.5), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}