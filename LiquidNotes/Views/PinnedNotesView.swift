//
//  PinnedNotesView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/18/25.
//

import SwiftUI
import SwiftData

struct PinnedNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isPinned == true }, sort: \Note.modifiedDate, order: .reverse) 
    private var pinnedNotes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Transparent background to allow Liquid Glass light blending
                Color.clear
                    .ignoresSafeArea()
                
                // Pinned Notes List
                if pinnedNotes.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "pin.slash")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)
                        Text("No pinned notes")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Pin notes to keep them at your fingertips")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(pinnedNotes, id: \.id) { note in
                            NoteCardView(
                                note: note,
                                onTap: {
                                    selectedNote = note
                                    showingNoteEditor = true
                                },
                                onDelete: {
                                    deleteNote(note)
                                },
                                onPin: {
                                    togglePin(note)
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Pinned")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewNote) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .background(Color.clear)
                    }
                    .background(Color.clear)
                    .interactiveGlassEffect(.regular, in: Circle())
                }
            }
            .onAppear {
                setupViewModels()
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .presentationDetents([.medium, .large])
            }
        }
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
        newNote.isPinned = true // Auto-pin new notes created from Pins tab
        selectedNote = newNote
        showingNoteEditor = true
    }
    
    private func deleteNote(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteNote(note)
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            for index in offsets {
                let note = pinnedNotes[index]
                viewModel.deleteNote(note)
            }
        }
        HapticManager.shared.noteDeleted()
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
    PinnedNotesView()
        .modelContainer(DataContainer.previewContainer)
}