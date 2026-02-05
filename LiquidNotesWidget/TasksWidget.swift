import SwiftUI
import WidgetKit

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry { TasksEntry(date: Date(), tasks: sample()) }
    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) { completion(TasksEntry(date: Date(), tasks: load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let entry = TasksEntry(date: Date(), tasks: load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    private func load() -> [TaskCard] {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.liquidnotes.shared")?.appendingPathComponent("widget_tasks.json") else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let items = try? dec.decode([WidgetTaskData].self, from: data) {
            return items.map { TaskCard(id: UUID(uuidString: $0.id) ?? UUID(), text: $0.text, isCompleted: $0.isCompleted, dueDate: $0.dueDate, priority: $0.priority) }
        }
        return []
    }
    private func sample() -> [TaskCard] {
        [TaskCard(id: UUID(), text: "Sample task", isCompleted: false, dueDate: Date().addingTimeInterval(3600), priority: "high")]
    }
}

struct TasksEntry: TimelineEntry { let date: Date; let tasks: [TaskCard] }
struct TaskCard: Identifiable { let id: UUID; let text: String; let isCompleted: Bool; let dueDate: Date?; let priority: String }

// Local mirror of the app-side JSON payload
struct WidgetTaskData: Codable {
    let id: String
    let text: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: String
}

struct TasksWidgetEntryView: View {
    var entry: TasksProvider.Entry
    @Environment(\.widgetFamily) var family
    var body: some View {
        ZStack {
            Color.clear
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .systemLarge: large
            default: small
            }
        }.containerBackground(.clear, for: .widget)
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header("Tasks")
            if let first = entry.tasks.first {
                taskRow(first).lineLimit(2)
            } else { empty }
            Spacer(minLength: 0)
        }.padding(10)
    }
    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Tasks")
            if entry.tasks.isEmpty { empty } else {
                ForEach(entry.tasks.prefix(3)) { task in taskRow(task) }
            }
            Spacer(minLength: 0)
        }.padding(10)
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("Tasks")
            if entry.tasks.isEmpty { empty } else {
                ForEach(entry.tasks.prefix(6)) { task in taskRow(task) }
            }
            Spacer(minLength: 0)
        }.padding(10)
    }
    private func header(_ title: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Text("\(entry.tasks.count)").font(.caption).foregroundStyle(.secondary) }
    }
    private func taskRow(_ t: TaskCard) -> some View {
        Link(destination: URL(string: "liquidnotes://tasks/\(t.id.uuidString)")!) {
        HStack(spacing: 6) {
            Image(systemName: t.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(t.isCompleted ? .green : .secondary)
            // Priority dot
            Circle().fill(priorityColor(t.priority)).frame(width: 6, height: 6)
            // Text
            Text(t.text)
                .font(.caption2)
                .foregroundStyle(t.isCompleted ? .secondary : .primary)
                .lineLimit(2)
            Spacer()
            // Due status
            if let due = t.dueDate {
                if due < Date(), !t.isCompleted {
                    Text("Overdue")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.2)))
                        .foregroundStyle(.red)
                } else {
                    Text(due, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }

    private func priorityColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "low": return .blue
        default: return .secondary.opacity(0.4)
        }
    }
    private var empty: some View { Text("No tasks").font(.caption2).foregroundStyle(.secondary) }
}

struct TasksWidget: Widget {
    let kind = "LiquidNotesTasksWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("Your standalone tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
