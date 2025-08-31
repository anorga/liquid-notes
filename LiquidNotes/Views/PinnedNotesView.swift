
import SwiftUI
import SwiftData

struct PinnedNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { note in note.isFavorited == true }, sort: \Note.modifiedDate, order: .reverse) 
    private var favoritedNotes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                VStack(alignment: .leading, spacing: 0) {
                    // Header aligned like Notes view
                    HStack {
                        Text("Favorites")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 5)

                    if favoritedNotes.isEmpty {
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("No favorites yet")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                Text("Tap the star on a note to add it here")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        SpatialCanvasView(
                            notes: favoritedNotes,
                            folders: [],
                            onTap: { note in
                                selectedNote = note
                                showingNoteEditor = true
                                HapticManager.shared.noteSelected()
                            },
                            onDelete: { note in deleteNote(note) },
                            onFavorite: { note in toggleFavorite(note) },
                            onFolderTap: nil,
                            onFolderDelete: nil,
                            onFolderFavorite: nil
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { setupViewModels() }
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
                let note = favoritedNotes[index]
                viewModel.deleteNote(note)
            }
        }
        HapticManager.shared.noteDeleted()
    }
    
    private func toggleFavorite(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.toggleNoteFavorite(note)
        }
        
        HapticManager.shared.buttonTapped()
    }
}

#Preview {
    PinnedNotesView()
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}