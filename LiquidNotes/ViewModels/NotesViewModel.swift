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
        // Assign to default folder if one exists (or create it if none present)
        let folderDescriptor = FetchDescriptor<Folder>()
        if let existingFolders = try? modelContext.fetch(folderDescriptor), let first = existingFolders.first {
            note.folder = first
        } else {
            // Create a default folder named "Folder" and assign
            let defaultFolder = Folder(name: "Folder")
            modelContext.insert(defaultFolder)
            note.folder = defaultFolder
        }
        modelContext.insert(note)
        
        saveContext()
        return note
    }

    /// Creates a note optionally in a provided folder; if folder supplied we do NOT auto-create or reassign.
    func createNote(in folder: Folder?, title: String = "", content: String = "") -> Note {
        let note = Note(title: title, content: content)
        let descriptor = FetchDescriptor<Note>()
        let existingNotes = (try? modelContext.fetch(descriptor)) ?? []
        let maxZIndex = existingNotes.lazy.map(\.zIndex).max() ?? 0
        note.zIndex = maxZIndex + 1
        if let folder = folder {
            note.folder = folder
        } else {
            // fall back to existing default assignment logic
            let folderDescriptor = FetchDescriptor<Folder>()
            if let existingFolders = try? modelContext.fetch(folderDescriptor), let first = existingFolders.first {
                note.folder = first
            } else {
                let defaultFolder = Folder(name: "Folder")
                modelContext.insert(defaultFolder)
                note.folder = defaultFolder
            }
        }
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
    
    func createFolder(name: String = "Folder") -> Folder {
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
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes.filter { !$0.isArchived }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Operators: #tag, is:fav, has:task, is:overdue, priority:<level>, due:yyyy-mm-dd, progress:>=NN, tag:any, tag:all
        var requiredTags: [String] = []
        var requireFavorite = false
        var requireHasTask = false
        var requireOverdue = false
        var priorityFilter: NotePriority? = nil
        var minProgress: Double? = nil
        var dueBefore: Date? = nil
        var tagModeAll = true // tag:any vs tag:all
        var textTerms: [String] = []
        query.split(separator: " ").forEach { tokenSub in
            let token = String(tokenSub)
            if token.hasPrefix("#") {
                let tag = String(token.dropFirst())
                if !tag.isEmpty { requiredTags.append(tag.lowercased()) }
            } else if token.lowercased() == "is:fav" || token.lowercased() == "is:favorite" { requireFavorite = true }
            else if token.lowercased() == "has:task" || token.lowercased() == "has:tasks" { requireHasTask = true }
            else if token.lowercased() == "is:overdue" { requireOverdue = true }
            else if token.lowercased().hasPrefix("priority:") {
                let val = token.split(separator: ":").dropFirst().joined().lowercased()
                if let p = NotePriority(rawValue: val) { priorityFilter = p }
            }
            else if token.lowercased().hasPrefix("progress:>") {
                if let num = Double(token.replacingOccurrences(of: "progress:>", with: "")) { minProgress = num/100.0 }
            }
            else if token.lowercased().hasPrefix("due:") {
                let dateStr = token.replacingOccurrences(of: "due:", with: "")
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; if let d = f.date(from: dateStr) { dueBefore = d }
            }
            else if token.lowercased() == "tag:any" { tagModeAll = false }
            else { textTerms.append(token) }
        }
        return notes.filter { note in
            if note.isArchived { return false }
            if requireFavorite && !note.isFavorited { return false }
            if requireHasTask && (note.tasks?.isEmpty ?? true) { return false }
            if let pf = priorityFilter, note.priority != pf { return false }
            if let mp = minProgress, note.progress < mp { return false }
            if requireOverdue, let due = note.dueDate { if due > Date() { return false } } else if requireOverdue && note.dueDate == nil { return false }
            if let db = dueBefore, let due = note.dueDate { if due > db { return false } } else if dueBefore != nil && note.dueDate == nil { return false }
            // Tags requirement: every required tag must exist (case-insensitive)
            if !requiredTags.isEmpty {
                let lowered = note.tags.map { $0.lowercased() }
                if tagModeAll {
                    for req in requiredTags where !lowered.contains(req) { return false }
                } else {
                    var matchAny = false
                    for req in requiredTags where lowered.contains(req) { matchAny = true; break }
                    if !matchAny { return false }
                }
            }
            // Text terms must each appear in title/content/tags/tasks
            if !textTerms.isEmpty {
                let tagsJoined = note.tags.joined(separator: " ")
                let tasksJoined = (note.tasks ?? []).map { $0.text }.joined(separator: " ")
                let haystack = (note.title + " " + note.content + " " + tagsJoined + " " + tasksJoined).lowercased()
                for term in textTerms {
                    if !haystack.contains(term.lowercased()) { return false }
                }
            }
            return true
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

    // Public wrapper to persist changes without exposing saveContext
    func persistChanges() {
        saveContext()
    }

    // Linking reindex removed for simplification.
}
