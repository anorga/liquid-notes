import SwiftUI
import SwiftData

struct PinnedNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { note in note.isFavorited == true && note.isSystem == false }, sort: \Note.modifiedDate, order: .reverse)
    private var favoritedNotes: [Note]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    struct NoteRef: Identifiable { let id: UUID }
    @State private var iPadEditorRef: NoteRef? = nil
    @State private var showingNoteEditor = false
    // Multi-select support for SpatialCanvasView
    @State private var selectedNoteIDs: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                VStack(alignment: .leading, spacing: 0) {
                    LNHeader(title: "Favorites", subtitle: "\(favoritedNotes.count) items") { EmptyView() }

                    if favoritedNotes.isEmpty {
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("No favorites yet")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                Text("Tap + to create your first favorite")
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
                            onFolderFavorite: nil,
                            selectionMode: false,
                            selectedNoteIDs: $selectedNoteIDs,
                            onToggleSelect: { _ in },
                            topContentInset: 12
                        )
                    }
                }
            }
            .overlay(alignment: .topTrailing) { floatingCreationButton }
            .navigationBarHidden(true)
            .onAppear { setupViewModels() }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $iPadEditorRef) { ref in
                let targetID = ref.id
                if let fetched = try? modelContext.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == targetID })).first {
                    NoteEditorView(note: fetched)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                } else {
                    Text("Note not found")
                }
            }
            .onChange(of: selectedNote) { _, newVal in
                if UIDevice.current.userInterfaceIdiom == .pad, let note = newVal {
                    iPadEditorRef = NoteRef(id: note.id)
                    selectedNote = nil
                }
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
    
    private func createNewFavoritedNote() {
        guard let viewModel = notesViewModel else { return }
        
        let newNote = viewModel.createNote(title: "", content: "")
        newNote.isFavorited = true
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving favorited note: \(error)")
        }
        
        selectedNote = newNote
        showingNoteEditor = true
        
        HapticManager.shared.noteCreated()
    }
    
    private var floatingCreationButton: some View {
        Button { 
            createNewFavoritedNote()
            HapticManager.shared.buttonTapped()
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
                .frame(width: 56, height: 56)
                .nativeGlassCircle()
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 20)
    }
}

#Preview {
    PinnedNotesView()
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}
