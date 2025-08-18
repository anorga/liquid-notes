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
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                
                // Notes List
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
                    List {
                        ForEach(filteredNotes, id: \.id) { note in
                            NoteCardView(
                                note: note,
                                onTap: {
                                    selectedNote = note
                                    showingNoteEditor = true
                                },
                                onDelete: {
                                    deleteNote(note)
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
                                    Circle()
                                        .fill(.blue.gradient)
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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
    
    private func deleteNotes(offsets: IndexSet) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            for index in offsets {
                let note = filteredNotes[index]
                viewModel.deleteNote(note)
            }
        }
        HapticManager.shared.noteDeleted()
    }
}

#Preview {
    ContentView()
        .modelContainer(DataContainer.previewContainer)
}
