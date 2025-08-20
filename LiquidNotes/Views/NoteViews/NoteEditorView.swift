//
//  NoteEditorView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var hasChanges = false
    @State private var isNewNote = false
    
    var body: some View {
        NavigationStack {
            // Using standard SwiftUI form components for automatic Liquid Glass
            VStack(spacing: 0) {
                // Title Field
                TextField("Note Title", text: $title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .onChange(of: title) { _, _ in
                        hasChanges = true
                    }
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                
                // Content Field
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Start typing your note...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    
                    TextEditor(text: $content)
                        .padding(.horizontal, 16)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .onChange(of: content) { _, _ in
                            hasChanges = true
                        }
                }
                
                Spacer()
            }
            // No background - let Liquid Glass handle transparency
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .foregroundStyle(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges && !isNewNote)
                    .foregroundStyle(.primary)
                    .opacity((hasChanges || isNewNote) ? 1.0 : 0.5)
                }
            }
            .onAppear {
                loadNoteData()
            }
        }
    }
    
    private func loadNoteData() {
        // Store the initial state before setting values that might trigger onChange
        let wasEmpty = note.title.isEmpty && note.content.isEmpty
        
        title = note.title
        content = note.content
        isNewNote = wasEmpty
        
        // Set hasChanges AFTER setting the title/content to avoid onChange interference
        if !isNewNote {
            hasChanges = false
        } else {
            // For new notes, initially allow saving
            hasChanges = true
        }
    }
    
    private func saveNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Always save the note when user explicitly chooses to save
        note.title = trimmedTitle
        note.content = trimmedContent
        note.updateModifiedDate()
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
            
            // Reset hasChanges after successful save
            hasChanges = false
        } catch {
            print("❌ Failed to save note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func cancelEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only delete new notes that are completely empty (user never typed anything)
        if isNewNote && trimmedTitle.isEmpty && trimmedContent.isEmpty {
            modelContext.delete(note)
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete empty note: \(error)")
            }
        }
        dismiss()
    }
}

#Preview {
    let sampleNote = Note(
        title: "Sample Note",
        content: "This is a sample note for preview"
    )
    
    NoteEditorView(note: sampleNote)
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}