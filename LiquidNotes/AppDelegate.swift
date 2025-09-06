import UIKit
import UserNotifications
import SwiftData
import WidgetKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        SharedDataManager.shared.setupNotificationCategories()
        SharedDataManager.shared.requestNotificationPermissions()
        // Ensure the widget has initial data on first launch / cold start
        Task { @MainActor in
            SharedDataManager.shared.refreshWidgetData()
        }
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard url.scheme == "liquidnotes" else { return false }
        
        if url.host == "note",
           let noteIDString = url.pathComponents.last,
           let noteID = UUID(uuidString: noteIDString) {
            NotificationCenter.default.post(
                name: .lnOpenNoteRequested,
                object: noteID
            )
            return true
        }
        
        if url.host == "create" {
            let action = url.pathComponents.last ?? ""
            switch action {
            case "note":
                NotificationCenter.default.post(name: .lnCreateAndLinkNoteRequested, object: "")
            case "task":
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .showQuickTaskCapture, object: nil)
                }
            default:
                break
            }
            return true
        }

        if url.host == "tasks" {
            // Open Tasks tab; optional last path component can be a taskID for future selection
            let taskIDString = url.pathComponents.dropFirst().first // /<taskID>
            NotificationCenter.default.post(name: .openTasksTab, object: taskIDString)
            return true
        }

        if url.host == "action" {
            let pathComponents = url.pathComponents
            guard pathComponents.count >= 3 else { return false }
            
            let action = pathComponents[1]
            let noteID = pathComponents[2]
            
            switch action {
            case "toggle-favorite":
                Task {
                    await WidgetInteractionManager.shared.toggleFavorite(noteID: noteID)
                }
            case "add-task":
                Task {
                    await WidgetInteractionManager.shared.addQuickTask(noteID: noteID)
                }
            case "complete-task":
                if pathComponents.count >= 4,
                   let taskIndex = Int(pathComponents[3]) {
                    Task {
                        await WidgetInteractionManager.shared.toggleTask(noteID: noteID, taskIndex: taskIndex)
                    }
                }
            default:
                break
            }
            return true
        }
        
        return false
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COMPLETE_TASK":
            if let taskIDString = userInfo["taskID"] as? String,
               let taskID = UUID(uuidString: taskIDString) {
                markTaskComplete(taskID: taskID)
            }
            
        case "SNOOZE_TASK":
            if let taskIDString = userInfo["taskID"] as? String,
               let taskID = UUID(uuidString: taskIDString) {
                snoozeTask(taskID: taskID)
            }
            
        case "OPEN_NOTE", UNNotificationDefaultActionIdentifier:
            if let noteIDString = userInfo["noteID"] as? String,
               let noteID = UUID(uuidString: noteIDString) {
                NotificationCenter.default.post(
                    name: .lnOpenNoteRequested,
                    object: noteID
                )
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func markTaskComplete(taskID: UUID) {
        Task { @MainActor in
            guard let container = try? ModelContainer(for: Note.self, NoteCategory.self, Folder.self) else { return }
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<Note>()
            guard let notes = try? context.fetch(descriptor) else { return }
            
            for note in notes {
                if let tasks = note.tasks,
                   let task = tasks.first(where: { $0.id == taskID }) {
                    task.isCompleted = true
                    note.updateModifiedDate()
                    try? context.save()
                    
                    SharedDataManager.shared.cancelTaskNotification(for: taskID)
                    SharedDataManager.shared.refreshWidgetData(context: context)
                    break
                }
            }
        }
    }
    
    private func snoozeTask(taskID: UUID) {
        Task { @MainActor in
            guard let container = try? ModelContainer(for: Note.self, NoteCategory.self, Folder.self) else { return }
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<Note>()
            guard let notes = try? context.fetch(descriptor) else { return }
            
            for note in notes {
                if let tasks = note.tasks,
                   let task = tasks.first(where: { $0.id == taskID }) {
                    let newDueDate = Date().addingTimeInterval(3600)
                    task.dueDate = newDueDate
                    note.updateModifiedDate()
                    try? context.save()
                    
                    SharedDataManager.shared.scheduleTaskNotification(for: task, in: note)
                    SharedDataManager.shared.refreshWidgetData(context: context)
                    break
                }
            }
        }
    }
}
