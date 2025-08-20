//
//  SpatialTabView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI
import SwiftData

struct SpatialTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var notes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                // Spatial Canvas Content
                if filteredNotes.isEmpty {
                    VStack {
                        Spacer()
                        Text("No notes yet")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Tap + to create your first note")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    SpatialCanvasView(
                        notes: filteredNotes,
                        onTap: { note in
                            selectedNote = note
                            showingNoteEditor = true
                        },
                        onDelete: deleteNote,
                        onPin: togglePin
                    )
                }
            }
            .navigationTitle("Canvas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddNoteButton(action: createNewNote)
                }
            }
            .onAppear {
                setupViewModels()
                print("🖼️ SpatialTabView appeared with \(notes.count) notes")
            }
            .onChange(of: notes.count) { oldCount, newCount in
                print("🖼️ SpatialTabView notes count changed: \(oldCount) → \(newCount)")
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private var filteredNotes: [Note] {
        guard let viewModel = notesViewModel else { return notes }
        return viewModel.filteredNotes(from: notes)
    }
    
    private func setupViewModels() {
        if notesViewModel == nil {
            notesViewModel = NotesViewModel(modelContext: modelContext)
        }
    }
    
    private func createNewNote() {
        HapticManager.shared.noteCreated()
        
        guard let viewModel = notesViewModel else { return }
        let newNote = viewModel.createNote()
        selectedNote = newNote
        showingNoteEditor = true
    }
    
    private func deleteNote(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteNote(note)
        }
    }
    
    private func togglePin(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.toggleNotePin(note)
        }
        
        HapticManager.shared.buttonTapped()
    }
}

#Preview {
    SpatialTabView()
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}