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
                // Enhanced gradient background with Apple system materials
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.8), location: 0.0),
                        .init(color: Color.orange.opacity(0.6), location: 0.5),
                        .init(color: Color(red: 0.0, green: 0.35, blue: 0.7).opacity(0.85), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
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
                    Button(action: createNewNote) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .symbolEffect(.bounce, value: false)
                            .symbolRenderingMode(.monochrome)
                            .background(Color.clear)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
            }
            .onAppear {
                setupViewModels()
                print("SpatialTabView appeared with \(notes.count) notes")
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
        .modelContainer(DataContainer.previewContainer)
}