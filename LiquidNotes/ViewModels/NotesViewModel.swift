//
//  NotesViewModel.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
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
    let descriptor = FetchDescriptor<Note>()
    let existingNotes = (try? modelContext.fetch(descriptor)) ?? []
        let maxZIndex = existingNotes.lazy.map(\.zIndex).max() ?? 0
        note.zIndex = maxZIndex + 1
        modelContext.insert(note)
        
        saveContext()
        return note
    }
    
    func updateNote(_ note: Note, title: String, content: String) {
        note.title = title
        note.content = content
        note.updateModifiedDate()
        saveContext()
    }
    
    func deleteNote(_ note: Note) {
        modelContext.delete(note)
        saveContext()
    }
    
    func toggleNoteFavorite(_ note: Note) {
        note.isFavorited.toggle()
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
    
    // MARK: - Folder Operations
    
    func createFolder(name: String = "New Folder") -> Folder {
        let folder = Folder(name: name)
        
        // Ensure new folders get the highest z-index
        let descriptor = FetchDescriptor<Folder>()
        let existingFolders = (try? modelContext.fetch(descriptor)) ?? []
        let maxZIndex = existingFolders.lazy.map(\.zIndex).max() ?? 0
        folder.zIndex = maxZIndex + 1
        
        modelContext.insert(folder)
        saveContext()
        return folder
    }
    
    func deleteFolder(_ folder: Folder) {
        if let notes = folder.notes {
            for note in notes {
                note.folder = nil
            }
        }
        modelContext.delete(folder)
        saveContext()
    }
    
    func toggleFolderFavorite(_ folder: Folder) {
        folder.isFavorited.toggle()
        folder.updateModifiedDate()
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
             note.content.localizedCaseInsensitiveContains(searchText))
             // || note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }) // Temporarily disabled
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
        } catch {
            print("❌ NotesViewModel: Save failed with error: \(error)")
            print("❌ NotesViewModel: Error details: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
        }
    }
}