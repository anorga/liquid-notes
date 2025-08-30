
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
                    
                if !favoritedNotes.isEmpty {
                    SpatialCanvasView(
                        notes: favoritedNotes,
                        folders: [],
                        onTap: { note in
                            selectedNote = note
                            showingNoteEditor = true
                            HapticManager.shared.noteSelected()
                        },
                        onDelete: { note in
                            deleteNote(note)
                        },
                        onFavorite: { note in
                            toggleFavorite(note)
                        },
                        onFolderTap: nil,
                        onFolderDelete: nil,
                        onFolderFavorite: nil
                    )
                }
                }
                .overlay(alignment: .center) {
                    if favoritedNotes.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 58))
                                .foregroundStyle(.tertiary)
                            Text("No Favorited Notes")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Tap the star on a note to pin it here for quick access.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 280)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.6))
                                .blendMode(.plusLighter)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.6)
                        )
                        .padding(.horizontal, 24)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("No favorited notes. Mark notes with a star to show them here."))
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