//
//  HomeView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var notes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
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
                
                // Remove floating add button - moved to toolbar
            }
            .navigationTitle("Liquid Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddNoteButton(action: createNewNote)
                }
            }
            .onAppear {
                setupViewModels()
                print("🏠 HomeView appeared with \(notes.count) notes")
            }
            .onChange(of: notes.count) { oldCount, newCount in
                print("🏠 HomeView notes count changed: \(oldCount) → \(newCount)")
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
        
        guard let viewModel = notesViewModel else { 
            print("❌ No viewModel available!")
            return 
        }
        
        print("🆕 Creating new note...")
        let newNote = viewModel.createNote()
        print("🆕 Created note with ID: \(newNote.id)")
        
        selectedNote = newNote
        showingNoteEditor = true
        print("🆕 Set selectedNote and showing editor")
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
    
    private func togglePin(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.toggleNotePin(note)
        }
        
        HapticManager.shared.buttonTapped()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}
