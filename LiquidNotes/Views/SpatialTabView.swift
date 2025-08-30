
import SwiftUI
import SwiftData

struct SpatialTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Folder.modifiedDate, order: .reverse) private var folders: [Folder]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    @AppStorage("showArchivedInPlace") private var showArchivedInPlace = false
    
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
                    filterBar
                    
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

    @AppStorage("activeFilterSelection") private var activeFilterSelection: Int = 0 // 0=AllActive,1=Archived,2=All
    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterChip(title: "Active", index: 0, selection: $activeFilterSelection)
            FilterChip(title: "Archived", index: 1, selection: $activeFilterSelection)
            FilterChip(title: "All", index: 2, selection: $activeFilterSelection)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .opacity(showArchivedInPlace ? 1 : 0.001)
        .animation(.easeInOut(duration: 0.3), value: showArchivedInPlace)
    }
    
    private var filteredNotes: [Note] {
        let active = allNotes.filter { !$0.isArchived }
        let archived = allNotes.filter { $0.isArchived }
        guard showArchivedInPlace else { return active }
        switch activeFilterSelection {
        case 1: return archived
        case 2: return active + archived
        default: return active
        }
    }
    

private struct FilterChip: View {
    let title: String
    let index: Int
    @Binding var selection: Int
    @ObservedObject private var themeManager = ThemeManager.shared
    var body: some View {
        let isOn = selection == index
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: isOn ? themeManager.currentTheme.primaryGradient : [Color.secondary.opacity(0.15), Color.secondary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(isOn ? themeManager.glassOpacity : 0.4)
                )
            )
            .overlay(
                Group { if isOn { Color.clear.liquidBorderHairline(cornerRadius: 40) } }
            )
            .foregroundStyle(isOn ? .primary : .secondary)
            .onTapGesture { withAnimation(.bouncy(duration: 0.3)) { selection = index; HapticManager.shared.buttonTapped() } }
    }
}
    private func setupViewModels() {
        if notesViewModel == nil {
            notesViewModel = NotesViewModel(modelContext: modelContext)
        }
        
        // Force a refresh of the @Query by checking the model context
    // (Removed verbose debug logging)
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