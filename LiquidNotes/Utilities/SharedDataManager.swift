import Foundation
import SwiftData
import WidgetKit
import UserNotifications
import CoreGraphics

class SharedDataManager {
    static let shared = SharedDataManager()
    static let appGroupID = "group.com.liquidnotes.shared"
    
    private init() {}
    
    var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    func saveNotesForWidget(notes: [Note]) {
        guard let containerURL = sharedContainerURL else { 
            print("🔴 SharedDataManager: No shared container URL found")
            return 
        }
        
        // Ensure the container directory exists
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("🔴 SharedDataManager: Failed to create container directory: \(error)")
            return
        }
        
        let widgetDataURL = containerURL.appendingPathComponent("widget_notes.json")
        
        let widgetNotes = notes.prefix(6).map { note in
            WidgetNoteData(
                id: note.id.uuidString,
                title: note.title,
                content: note.content,
                isFavorited: note.isFavorited,
                hasTask: !(note.tasks?.isEmpty ?? true),
                taskCount: note.tasks?.count ?? 0,
                completedTaskCount: note.tasks?.filter { $0.isCompleted }.count ?? 0,
                modifiedDate: note.modifiedDate,
                tags: note.tags
            )
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let newData = try encoder.encode(widgetNotes)
            // If data hasn't changed, skip writing and reloading timelines
            if let existingData = try? Data(contentsOf: widgetDataURL), existingData == newData {
                #if DEBUG
                print("🟡 SharedDataManager: Widget data unchanged; skipping write/reload")
                #endif
                return
            }
            try newData.write(to: widgetDataURL, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
            #if DEBUG
            print("🟢 SharedDataManager: Widget timeline reload requested at \(Date())")
            #endif
        } catch {
            print("🔴 SharedDataManager: Failed to save widget data: \(error)")
        }
    }
    
    func loadNotesForWidget() -> [WidgetNoteData] {
        guard let containerURL = sharedContainerURL else { return [] }
        
        let widgetDataURL = containerURL.appendingPathComponent("widget_notes.json")
        
        do {
            let data = try Data(contentsOf: widgetDataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WidgetNoteData].self, from: data)
        } catch {
            print("Failed to load widget data: \(error)")
            return []
        }
    }

    // Centralized helper to compute the widget dataset and persist it to the app group.
    // Keep this logic identical to previous scattered implementations.
    @MainActor
    func refreshWidgetData(context: ModelContext) {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.modifiedDate, order: .reverse)]
        )
        if let notes = try? context.fetch(descriptor) {
            let favoriteNotes = notes.filter { $0.isFavorited && !$0.isArchived }
            let recentNotes = notes.filter { !$0.isArchived && !$0.isSystem }
            let notesToShow = favoriteNotes.isEmpty ? recentNotes : favoriteNotes
            saveNotesForWidget(notes: Array(notesToShow.prefix(6)))
        }
    }

    // Convenience: build a temporary container and refresh without a provided context.
    // Use sparingly; prefer the context-aware variant when available.
    @MainActor
    func refreshWidgetData() {
        if let container = try? ModelContainer(for: Note.self, NoteCategory.self, Folder.self) {
            let context = container.mainContext
            refreshWidgetData(context: context)
        }
    }
    
    func scheduleTaskNotification(for task: TaskItem, in note: Note) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.text
        content.subtitle = "From: \(note.title)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = [
            "noteID": note.id.uuidString,
            "taskID": task.id.uuidString,
            "taskTitle": task.text,
            "noteTitle": note.title
        ]
        
        // Add rich media if note has attachments
        if let attachment = createNotificationAttachment(for: note) {
            content.attachments = [attachment]
        }
        
        // Set thread identifier for grouping
        content.threadIdentifier = "note-\(note.id.uuidString)"
        
        // Removed deprecated summary properties (iOS 15+)
        
        let trigger: UNNotificationTrigger
        
        if dueDate > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            return
        }
        
        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func cancelTaskNotification(for taskID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task-\(taskID.uuidString)"]
        )
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Error requesting notifications: \(error)")
            }
        }
    }
    
    func setupNotificationCategories() {
        // Task reminder actions
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Mark Complete",
            options: [.destructive]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_TASK",
            title: "Remind in 1 hour",
            options: []
        )
        
        let snooze30Action = UNNotificationAction(
            identifier: "SNOOZE_30MIN",
            title: "30 minutes",
            options: []
        )
        
        let openAction = UNNotificationAction(
            identifier: "OPEN_NOTE",
            title: "Open Note",
            options: [.foreground]
        )
        
        let addTaskAction = UNNotificationAction(
            identifier: "ADD_TASK",
            title: "Add Task",
            options: [.foreground]
        )
        
        // Task reminder category with enhanced actions
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction, snooze30Action, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )
        
        // Daily review category
        let reviewAction = UNNotificationAction(
            identifier: "START_REVIEW",
            title: "Start Review",
            options: [.foreground]
        )
        
        let skipReviewAction = UNNotificationAction(
            identifier: "SKIP_REVIEW",
            title: "Skip Today",
            options: [.destructive]
        )
        
        let dailyReviewCategory = UNNotificationCategory(
            identifier: "DAILY_REVIEW",
            actions: [reviewAction, skipReviewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Note reminder category
        let favoriteAction = UNNotificationAction(
            identifier: "FAVORITE_NOTE",
            title: "Add to Favorites",
            options: []
        )
        
        let noteReminderCategory = UNNotificationCategory(
            identifier: "NOTE_REMINDER",
            actions: [favoriteAction, addTaskAction, openAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            taskCategory,
            dailyReviewCategory,
            noteReminderCategory
        ])
    }
    
    private func createNotificationAttachment(for note: Note) -> UNNotificationAttachment? {
        // Try to get the first image attachment from the note
        guard let firstImageData = note.attachments.first else { return nil }
        
        // Create temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "notification_\(note.id.uuidString).jpg"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try firstImageData.write(to: fileURL)
            
            let attachment = try UNNotificationAttachment(
                identifier: "note-image",
                url: fileURL,
                options: [
                    UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg",
                    UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0, y: 0, width: 1, height: 0.75).dictionaryRepresentation
                ]
            )
            
            return attachment
        } catch {
            print("Failed to create notification attachment: \(error)")
            return nil
        }
    }
    
    func scheduleNoteReminder(for note: Note, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Note Reminder"
        content.body = note.title.isEmpty ? "Untitled Note" : note.title
        content.subtitle = note.content.prefix(50).description + (note.content.count > 50 ? "..." : "")
        content.sound = .default
        content.categoryIdentifier = "NOTE_REMINDER"
        content.userInfo = [
            "noteID": note.id.uuidString,
            "noteTitle": note.title
        ]
        
        if let attachment = createNotificationAttachment(for: note) {
            content.attachments = [attachment]
        }
        
        content.threadIdentifier = "note-reminder-\(note.id.uuidString)"
        
        let trigger: UNNotificationTrigger
        
        if date > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            return
        }
        
        let request = UNNotificationRequest(
            identifier: "note-reminder-\(note.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule note reminder: \(error)")
            }
        }
    }
}

struct WidgetNoteData: Codable {
    let id: String
    let title: String
    let content: String
    let isFavorited: Bool
    let hasTask: Bool
    let taskCount: Int
    let completedTaskCount: Int
    let modifiedDate: Date
    let tags: [String]
}
