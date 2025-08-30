
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
                    
                    if filteredNotes.isEmpty {
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("No notes yet")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                Text("Tap + to create your first note")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let _ = print("SpatialTabView: showing SpatialCanvasView with \(filteredNotes.count) notes")
                        SpatialCanvasView(
                            notes: filteredNotes,
                            folders: folders,
                            onTap: { note in
                                selectedNote = note
                                showingNoteEditor = true
                            },
                            onDelete: deleteNote,
                            onFavorite: toggleFavorite,
                            onFolderTap: nil,
                            onFolderDelete: deleteFolder,
                            onFolderFavorite: toggleFolderFavorite
                        )
                    }
                }
            }
            .navigationBarHidden(true)
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
        print("SpatialTabView: notes.count = \(notes.count)")
        guard let viewModel = notesViewModel else {
            print("SpatialTabView: no viewModel, returning raw notes: \(notes.count)")
            return notes
        }
        let filtered = viewModel.filteredNotes(from: notes)
        print("SpatialTabView: filtered notes: \(filtered.count)")
        return filtered
    }
    
    private func setupViewModels() {
        print("SpatialTabView: setupViewModels called, current notesViewModel: \(notesViewModel != nil ? "exists" : "nil")")
        if notesViewModel == nil {
            notesViewModel = NotesViewModel(modelContext: modelContext)
            print("SpatialTabView: notesViewModel created")
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