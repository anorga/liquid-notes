//
//  NotesViewModel.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

@Observable
class NotesViewModel {
    private var modelContext: ModelContext
    
    var searchText = ""
    // Removed selectedThemeID - no longer using themes
    var isEditMode = false
    var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle, syncing, success, error(String)
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Note Operations
    
    func createNote(title: String = "", content: String = "") -> Note {
        let note = Note(title: title, content: content)
        
        // Ensure new notes get the highest z-index (NEVER modifies existing notes)
        let descriptor = FetchDescriptor<Note>()
        let existingNotes = (try? modelContext.fetch(descriptor)) ?? []
        let maxZIndex = existingNotes.lazy.map(\.zIndex).max() ?? 0
        note.zIndex = maxZIndex + 1
        
        // Note starts with positionX=0, positionY=0 and will be positioned by canvas initialization
        // This NEVER moves existing notes
        
        print("📝 Creating new note with ID: \(note.id)")
        modelContext.insert(note)
        saveContext()
        print("✅ Note inserted and saved to context")
        return note
    }
    
    func updateNote(_ note: Note, title: String, content: String) {
        note.title = title
        note.content = content
        note.updateModifiedDate()
        saveContext()
    }
    
    func deleteNote(_ note: Note) {
        print("🗑️ Deleting note: '\(note.title.isEmpty ? "(untitled)" : note.title)' with ID: \(note.id)")
        modelContext.delete(note)
        saveContext()
    }
    
    func toggleNotePin(_ note: Note) {
        note.isPinned.toggle()
        note.updateModifiedDate()
        saveContext()
    }
    
    func archiveNote(_ note: Note) {
        note.isArchived = true
        note.updateModifiedDate()
        saveContext()
    }
    
    func updateNotePosition(_ note: Note, x: Float, y: Float) {
        note.positionX = x
        note.positionY = y
        note.updateModifiedDate()
        saveContext()
    }
    
    // Removed updateNoteTheme - no longer using themes
    
    // MARK: - Category Operations
    
    func createCategory(name: String, color: String = "blue") -> NoteCategory {
        let category = NoteCategory(name: name, color: color)
        modelContext.insert(category)
        saveContext()
        return category
    }
    
    func deleteCategory(_ category: NoteCategory) {
        modelContext.delete(category)
        saveContext()
    }
    
    // MARK: - Search and Filtering
    
    func filteredNotes(from notes: [Note]) -> [Note] {
        if searchText.isEmpty {
            return notes.filter { !$0.isArchived }
        }
        
        return notes.filter { note in
            !note.isArchived &&
            (note.title.localizedCaseInsensitiveContains(searchText) ||
             note.content.localizedCaseInsensitiveContains(searchText) ||
             note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    // MARK: - Cloud Sync
    
    func forceSyncWithCloud() {
        syncStatus = .syncing
        
        // SwiftData handles CloudKit sync automatically
        // This is just for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncStatus = .success
            
            // Reset to idle after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.syncStatus = .idle
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func saveContext() {
        do {
            try modelContext.save()
            print("💾 Context saved successfully")
        } catch {
            print("❌ Failed to save context: \(error)")
            syncStatus = .error(error.localizedDescription)
        }
    }
}