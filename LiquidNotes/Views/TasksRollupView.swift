import SwiftUI
import SwiftData

struct TasksRollupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @State private var search = ""
    @State private var showCompleted = true
    @State private var selectedPriority: NotePriority? = nil
    @State private var expandedNotes: Set<UUID> = []
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
    }
    private var filteredNotes: [Note] {
        allNotes.filter { n in
            !(n.tasks?.isEmpty ?? true)
        }.filter { n in
            search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || n.title.localizedCaseInsensitiveContains(search) || (n.tasks ?? []).contains { $0.text.localizedCaseInsensitiveContains(search) }
        }.filter { n in
            if let p = selectedPriority { return n.priority == p } else { return true }
        }.sorted { lhs, rhs in
            // Sort by priority then progress asc then modifiedDate desc
            let priorityOrder: [NotePriority:Int] = [.urgent:0, .high:1, .normal:2, .low:3]
            if lhs.priority != rhs.priority { return priorityOrder[lhs.priority, default: 4] < priorityOrder[rhs.priority, default: 4] }
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
                        if let due = note.dueDate { Text(due, style: .date).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Color.orange.opacity(0.15))).foregroundStyle(.orange) }
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
                        Button(action: { task.isCompleted.toggle(); note.updateProgress(); try? modelContext.save() }) { Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundStyle(task.isCompleted ? Color.green : Color.secondary) }.buttonStyle(.plain)
                        Text(task.text).strikethrough(task.isCompleted, color: .primary.opacity(0.6)).foregroundStyle(task.isCompleted ? .secondary : .primary).lineLimit(3)
                        Spacer()
                        Button(role: .destructive, action: { note.removeTask(at: idx); try? modelContext.save() }) { Image(systemName: "trash").font(.caption2) }.buttonStyle(.borderless)
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