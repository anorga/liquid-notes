import Foundation
import SwiftData
import WidgetKit
import Combine

@MainActor
class WidgetInteractionManager: ObservableObject {
    static let shared = WidgetInteractionManager()
    
    private init() {}
    
    func toggleFavorite(noteID: String) async {
        do {
            let container = try ModelContainer(for: Note.self, NoteCategory.self, Folder.self)
            let context = container.mainContext
            
            guard let uuid = UUID(uuidString: noteID) else { return }
            
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id == uuid
                }
            )
            
            guard let notes = try? context.fetch(descriptor),
                  let note = notes.first else {
                return
            }
            
            note.isFavorited.toggle()
            note.updateModifiedDate()
            
            try context.save()
            
            // Update widget data
            updateWidgetData(context: context)
            
            // Show feedback
            HapticManager.shared.buttonTapped()
            
        } catch {
            print("Error toggling favorite from widget: \(error)")
        }
    }
    
    func addQuickTask(noteID: String) async {
        do {
            let container = try ModelContainer(for: Note.self, NoteCategory.self, Folder.self)
            let context = container.mainContext
            
            guard let uuid = UUID(uuidString: noteID) else { return }
            
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id == uuid
                }
            )
            
            guard let notes = try? context.fetch(descriptor),
                  let note = notes.first else {
                return
            }
            
            note.addTask("Quick task from widget")
            
            try context.save()
            
            // Update widget data
            updateWidgetData(context: context)
            
            // Live Activity functionality removed to prevent cross-target issues
            
            HapticManager.shared.noteCreated()
            
        } catch {
            print("Error adding quick task from widget: \(error)")
        }
    }
    
    func toggleTask(noteID: String, taskIndex: Int) async {
        do {
            let container = try ModelContainer(for: Note.self, NoteCategory.self, Folder.self)
            let context = container.mainContext
            
            guard let uuid = UUID(uuidString: noteID) else { return }
            
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id == uuid
                }
            )
            
            guard let notes = try? context.fetch(descriptor),
                  let note = notes.first,
                  let tasks = note.tasks,
                  taskIndex < tasks.count else {
                return
            }
            
            let task = tasks[taskIndex]
            let wasCompleted = task.isCompleted
            
            note.toggleTask(at: taskIndex)
            
            try context.save()
            
            // Update widget data
            updateWidgetData(context: context)
            
            // Live Activity updates removed to prevent cross-target issues
            
            // Update badge count
            BadgeManager.shared.updateBadgeCount()
            
            HapticManager.shared.buttonTapped()
            
            if !wasCompleted && task.isCompleted {
                HapticManager.shared.success()
            }
            
        } catch {
            print("Error toggling task from widget: \(error)")
        }
    }
    
    private func updateWidgetData(context: ModelContext) {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.modifiedDate, order: .reverse)]
        )
        
        if let notes = try? context.fetch(descriptor) {
            let favoriteNotes = notes.filter { $0.isFavorited && !$0.isArchived }
            let recentNotes = notes.filter { !$0.isArchived && !$0.isSystem }
            
            let notesToShow = favoriteNotes.isEmpty ? recentNotes : favoriteNotes
            SharedDataManager.shared.saveNotesForWidget(notes: Array(notesToShow.prefix(6)))
        }
        
        // Refresh all widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
}