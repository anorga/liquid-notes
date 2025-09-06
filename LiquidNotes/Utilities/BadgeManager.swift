import Foundation
import SwiftData
import UIKit
import Combine
import UserNotifications

@MainActor
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    
    @Published var currentBadgeCount: Int = 0
    
    private init() {}
    
    func updateBadgeCount() {
        Task {
            await calculateAndSetBadgeCount()
        }
    }
    
    private func calculateAndSetBadgeCount() async {
        do {
            let container = try ModelContainer(for: Note.self, NoteCategory.self, Folder.self, TaskItem.self)
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    !note.isArchived && !note.isSystem
                }
            )
            
            guard let notes = try? context.fetch(descriptor) else {
                setBadgeCount(0)
                return
            }
            
            var overdueCount = 0
            var urgentCount = 0
            
            for note in notes {
                if let tasks = note.tasks {
                    for task in tasks where !task.isCompleted {
                        if let dueDate = task.dueDate {
                            let timeUntilDue = dueDate.timeIntervalSinceNow
                            
                            if timeUntilDue < 0 {
                                // Overdue task
                                overdueCount += 1
                            } else if timeUntilDue < 7200 { // 2 hours
                                // Urgent task (due within 2 hours)
                                urgentCount += 1
                            }
                        }
                    }
                }
                // Optionally include note-level due dates
                if let noteDue = note.dueDate {
                    let t = noteDue.timeIntervalSinceNow
                    if t < 0 { overdueCount += 1 } else if t < 7200 { urgentCount += 1 }
                }
            }
            // Include standalone tasks (note == nil)
            let standaloneDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.note == nil }
            )
            let standalone = (try? context.fetch(standaloneDescriptor)) ?? []
            for task in standalone where !task.isCompleted {
                if let dueDate = task.dueDate {
                    let t = dueDate.timeIntervalSinceNow
                    if t < 0 { overdueCount += 1 } else if t < 7200 { urgentCount += 1 }
                }
            }
            
            // Prioritize overdue tasks, then urgent tasks
            let badgeCount = overdueCount > 0 ? overdueCount : urgentCount
            setBadgeCount(badgeCount)
            
        } catch {
            print("Error calculating badge count: \(error)")
            setBadgeCount(0)
        }
    }
    
    private func setBadgeCount(_ count: Int) {
        currentBadgeCount = count
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("Failed to set badge count: \(error)")
            }
        }
        
        // Update shared preferences for widgets
        if let containerURL = SharedDataManager.shared.sharedContainerURL {
            let badgeURL = containerURL.appendingPathComponent("badge_count.json")
            let badgeData = BadgeData(count: count, lastUpdated: Date())
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(badgeData)
                try data.write(to: badgeURL)
            } catch {
                print("Failed to save badge data: \(error)")
            }
        }
    }
    
    func clearBadge() {
        setBadgeCount(0)
    }
    
    func getBadgeData() -> BadgeData {
        guard let containerURL = SharedDataManager.shared.sharedContainerURL else {
            return BadgeData(count: 0, lastUpdated: Date())
        }
        
        let badgeURL = containerURL.appendingPathComponent("badge_count.json")
        
        do {
            let data = try Data(contentsOf: badgeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BadgeData.self, from: data)
        } catch {
            return BadgeData(count: 0, lastUpdated: Date())
        }
    }
    
    // Called when app becomes active
    func refreshBadgeCount() {
        updateBadgeCount()
    }
    
    // Called when tasks are completed
    func taskCompleted() {
        // Delay update to allow database to save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateBadgeCount()
        }
    }
    
    // Called when new tasks are added
    func taskAdded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateBadgeCount()
        }
    }
}

struct BadgeData: Codable {
    let count: Int
    let lastUpdated: Date
}
