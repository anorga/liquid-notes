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
                    .background(Color.clear)
                    .interactiveGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                    .background(Color.clear)
                    .interactiveGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .onAppear {
                loadNoteData()
            }
        }
    }
    
    private func loadNoteData() {
        title = note.title
        content = note.content
        // Check if this is a new note (empty title and content)
        isNewNote = note.title.isEmpty && note.content.isEmpty
    }
    
    private func saveNote() {
        note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        note.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        note.updateModifiedDate()
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            print("Failed to save note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func cancelEdit() {
        // If it's a new note with no content, delete it
        if isNewNote && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(note)
            try? modelContext.save()
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
        .modelContainer(DataContainer.previewContainer)
}