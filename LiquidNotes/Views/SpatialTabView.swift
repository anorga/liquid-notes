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
    @Query(sort: \Folder.modifiedDate, order: .reverse) private var folders: [Folder]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header section - same layout as PinnedNotesView
                    HStack {
                        Text("Notes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    
                    // Canvas section
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
                        .padding()
                    } else {
                        SpatialCanvasView(
                            notes: filteredNotes,
                            folders: folders,
                            onTap: { note in
                                selectedNote = note
                                showingNoteEditor = true
                            },
                            onDelete: deleteNote,
                            onFavorite: toggleFavorite,
                            onFolderTap: nil, // TODO: Implement folder opening
                            onFolderDelete: deleteFolder,
                            onFolderFavorite: toggleFolderFavorite
                        )
                    }
                }
            }
            .navigationBarHidden(true)
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
    
    private func createNewFolder() {
        HapticManager.shared.buttonTapped()
        
        guard let viewModel = notesViewModel else { return }
        let _ = viewModel.createFolder()
    }
    
    private func deleteNote(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteNote(note)
        }
    }
    
    private func toggleFavorite(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.toggleNoteFavorite(note)
        }
        
        HapticManager.shared.buttonTapped()
    }
    
    private func deleteFolder(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteFolder(folder)
        }
    }
    
    private func toggleFolderFavorite(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.toggleFolderFavorite(folder)
        }
        
        HapticManager.shared.buttonTapped()
    }
}

#Preview {
    SpatialTabView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}