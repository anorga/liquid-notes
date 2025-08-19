//
//  ContentView.swift
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
                // Very dark blue and orange gradient
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
        .modelContainer(DataContainer.previewContainer)
}
