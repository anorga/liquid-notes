//
//  LiquidNotesWidgetLiveActivity.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct TaskActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var noteTitle: String
        var isCompleted: Bool
        var progress: Double
        var totalTasks: Int
        var completedTasks: Int
        var dueDate: Date?
        var priority: ActivityTaskPriority
    }

    var taskID: String
    var noteID: String
    var startTime: Date
}

enum ActivityTaskPriority: String, Codable, Hashable {
    case low, medium, high, urgent
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.circle"
        case .medium: return "clock"
        case .high: return "exclamationmark.circle"
        case .urgent: return "flame"
        }
    }
}

struct LiquidNotesLiveActivity {
    static let activityConfiguration =
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            LockScreenTaskView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Image(systemName: context.state.priority.icon)
                            .foregroundColor(context.state.priority.color)
                            .font(.title2)
                        
                        if let dueDate = context.state.dueDate {
                            Text(dueDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Text("\(context.state.completedTasks)/\(context.state.totalTasks)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: context.state.progress)
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 30, height: 30)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.state.taskTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Text("in \(context.state.noteTitle)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if !context.state.isCompleted {
                            Button(intent: CompleteTaskIntent(
                                taskID: context.attributes.taskID,
                                noteID: context.attributes.noteID
                            )) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: context.state.priority.icon)
                    .foregroundColor(context.state.priority.color)
            } compactTrailing: {
                Text("\(context.state.completedTasks)/\(context.state.totalTasks)")
                    .font(.caption2)
                    .fontWeight(.bold)
            } minimal: {
                Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : context.state.priority.icon)
                    .foregroundColor(context.state.isCompleted ? .green : context.state.priority.color)
            }
            .widgetURL(URL(string: "liquidnotes://note/\(context.attributes.noteID)"))
            .keylineTint(context.state.priority.color)
        }
}

struct LockScreenTaskView: View {
    let context: ActivityViewContext<TaskActivityAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Image(systemName: context.state.priority.icon)
                    .font(.title)
                    .foregroundColor(context.state.priority.color)
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 25, height: 25)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.taskTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack {
                    Text("in \(context.state.noteTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let dueDate = context.state.dueDate {
                        Text(dueDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("\(context.state.completedTasks)/\(context.state.totalTasks) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !context.state.isCompleted {
                        Button(intent: CompleteTaskIntent(
                            taskID: context.attributes.taskID,
                            noteID: context.attributes.noteID
                        )) {
                            Text("Complete")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .activitySystemActionForegroundColor(.primary)
    }
}

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    
    @Parameter(title: "Task ID")
    var taskID: String
    
    @Parameter(title: "Note ID") 
    var noteID: String
    
    init() {}
    
    init(taskID: String, noteID: String) {
        self.taskID = taskID
        self.noteID = noteID
    }
    
    func perform() async throws -> some IntentResult {
        // Use URL scheme to trigger action in main app
        guard let url = URL(string: "liquidnotes://action/complete-task/\(noteID)/\(taskID)") else {
            return .result()
        }
        
        return .result(opensIntent: OpenURLIntent(url))
    }
}

extension TaskActivityAttributes {
    fileprivate static var preview: TaskActivityAttributes {
        TaskActivityAttributes(
            taskID: UUID().uuidString,
            noteID: UUID().uuidString,
            startTime: Date()
        )
    }
}

extension TaskActivityAttributes.ContentState {
    fileprivate static var active: TaskActivityAttributes.ContentState {
        TaskActivityAttributes.ContentState(
            taskTitle: "Finish project proposal",
            noteTitle: "Work Tasks",
            isCompleted: false,
            progress: 0.6,
            totalTasks: 5,
            completedTasks: 3,
            dueDate: Date().addingTimeInterval(3600),
            priority: .high
        )
    }
    
    fileprivate static var urgent: TaskActivityAttributes.ContentState {
        TaskActivityAttributes.ContentState(
            taskTitle: "Submit quarterly report",
            noteTitle: "Deadlines",
            isCompleted: false,
            progress: 0.2,
            totalTasks: 3,
            completedTasks: 1,
            dueDate: Date().addingTimeInterval(1800),
            priority: .urgent
        )
    }
}

#if DEBUG
struct LiquidNotesLiveActivity_Previews: PreviewProvider {
    static let attributes = TaskActivityAttributes.preview
    static let contentState = TaskActivityAttributes.ContentState.active

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
    }
}
#endif
