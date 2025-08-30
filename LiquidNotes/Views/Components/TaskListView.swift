import SwiftUI

struct TaskListView: View {
    @Binding var tasks: [TaskItem]
    let onToggle: (Int) -> Void
    let onDelete: (Int) -> Void
    let onAdd: (String) -> Void
    
    @State private var newTaskText = ""
    @State private var isAddingTask = false
    
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
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRowView(
                            task: task,
                            onToggle: {
                                withAnimation(.bouncy(duration: 0.3)) {
                                    onToggle(index)
                                }
                            },
                            onDelete: {
                                withAnimation(.bouncy(duration: 0.4)) {
                                    onDelete(index)
                                }
                            }
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
        onAdd(newTaskText)
        newTaskText = ""
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
                            colors: [.secondary, .tertiary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            
            Text(task.text)
                .font(.callout)
                .fontWeight(task.isCompleted ? .regular : .medium)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted, color: .secondary)
                .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
            
            Spacer()
            
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
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onToggle()
        }
    }
}

struct ProgressCircle: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.secondary.opacity(0.2), .tertiary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
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