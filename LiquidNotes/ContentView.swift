//
//  ContentView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var notes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var glassEffectsViewModel = GlassEffectsViewModel()
    @State private var motionManager = MotionManager()
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                
                // Notes Canvas
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredNotes, id: \.id) { note in
                            NoteCardView(
                                note: note,
                                theme: GlassTheme.theme(for: note.glassThemeID),
                                motionData: motionManager.data,
                                onTap: {
                                    selectedNote = note
                                    showingNoteEditor = true
                                },
                                onDelete: {
                                    deleteNote(note)
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: createNewNote) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LiquidGlassView(
                                        theme: glassEffectsViewModel.currentTheme,
                                        motionData: motionManager.data
                                    ) {
                                        Circle()
                                            .fill(.blue.gradient)
                                    }
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Liquid Notes")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                setupViewModels()
                motionManager.startTracking()
            }
            .onDisappear {
                motionManager.stopTracking()
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
}

// Temporary placeholder for NoteEditorView
struct NoteEditorView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Note Editor")
                    .font(.title)
                Text("Editing: \(note.title.isEmpty ? "Untitled" : note.title)")
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(DataContainer.previewContainer)
}
