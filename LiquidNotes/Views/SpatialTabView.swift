import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

struct SpatialTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Folder.modifiedDate, order: .reverse) private var folders: [Folder]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    // Multi-select state
    @State private var selectionMode: Bool = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var showingMoveSheet: Bool = false
    @State private var moveTargetFolder: Folder? = nil
    @AppStorage("foldersCollapsed") private var foldersCollapsed: Bool = false
    @State private var batchActionAnimating: Bool = false
    @State private var dropHoverFolderID: UUID? = nil
    // Archived inline option removed; filters always visible
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                VStack(alignment: .leading, spacing: 0) {
                    LNHeader(title: "Notes", subtitle: "\(allNotes.filter{ !$0.isArchived }.count) active") { EmptyView() }
                    folderSection
                    
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
                            onFolderFavorite: toggleFolderFavorite,
                            selectionMode: selectionMode,
                            selectedNoteIDs: $selectedNoteIDs,
                            onToggleSelect: { note in toggleSelect(note) }
                        )
                    }
                }
                .overlay(alignment: .bottom) { if selectionMode { batchActionBar.transition(.move(edge: .bottom).combined(with: .opacity)) } }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupViewModels()
            }
            .onDisappear { clearSelection() }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .presentationDetents(
                        UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium, .large]
                    )
            }
            .sheet(isPresented: $showingMoveSheet) { moveSheet }
        }
    }

    // Removed archive filter chips per simplification

    // headerBar removed (replaced with LNHeader)

    @State private var newFolderName: String = ""
    @State private var renamingFolder: Folder? = nil
    @FocusState private var folderNameFocused: Bool
    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(folders) { folder in
                    folderChip(folder)
                }
                Button {
                    newFolderName = ""
                    withAnimation { renamingFolder = nil }
                    createNewFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .font(.caption2)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }
    @State private var selectedFolder: Folder? = nil
    private func folderChip(_ folder: Folder) -> some View {
        let isSelectedFolder = selectedFolder?.id == folder.id
        let isRenaming = renamingFolder?.id == folder.id
        // Precompute style values to reduce type-checker load.
        let baseFill: Color = {
            if dropHoverFolderID == folder.id { return Color.accentColor.opacity(0.4) }
            if isSelectedFolder { return Color.accentColor.opacity(0.25) }
            return Color.secondary.opacity(0.1)
        }()
        let strokeColor: Color = isRenaming ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.18)
        let strokeWidth: CGFloat = isRenaming ? 1.2 : 0.5
        let isTargetedBinding = Binding<Bool>(
            get: { dropHoverFolderID == folder.id },
            set: { hovering in
                if hovering { dropHoverFolderID = folder.id }
                else if dropHoverFolderID == folder.id { dropHoverFolderID = nil }
            }
        )

        return HStack(spacing: 6) {
            folderIcon(folder: folder, highlighted: isSelectedFolder)
            if isRenaming { renameEditor(for: folder) } else { folderLabel(folder: folder, highlighted: isSelectedFolder) }
            if !isRenaming { favoriteButton(folder) }
            if !isRenaming { folderMenu(folder) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(baseFill))
        .overlay(Capsule().stroke(strokeColor, lineWidth: strokeWidth))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration:0.22), value: isRenaming)
        .onDrop(of: [UTType.text], isTargeted: isTargetedBinding) { providers in handleDrop(providers: providers, into: folder) }
    }

    // MARK: - Folder chip subviews (extracted for compiler performance)
    private func folderIcon(folder: Folder, highlighted: Bool) -> some View {
        Image(systemName: folder.isFavorited ? "folder.fill" : "folder")
            .foregroundStyle(highlighted ? Color.accentColor : .secondary)
    }
    private func folderLabel(folder: Folder, highlighted: Bool) -> some View {
        Text(folder.name)
            .font(.caption2)
            .fontWeight(highlighted ? .semibold : .regular)
            .lineLimit(1)
            .onTapGesture { withAnimation(.bouncy(duration:0.35)) { selectedFolder = highlighted ? nil : folder } }
    }
    private func renameEditor(for folder: Folder) -> some View {
        HStack(spacing: 4) {
            TextField("Name", text: Binding(get: { folder.name }, set: { folder.name = $0 }))
                .font(.caption2)
                .textFieldStyle(.plain)
                .frame(minWidth: 70)
                .focused($folderNameFocused)
            Button { commitRename(folder) } label: { Image(systemName: "checkmark").font(.caption2) }
                .buttonStyle(.plain)
                .accessibilityLabel("Save folder name")
            Button { cancelRename() } label: { Image(systemName: "xmark").font(.caption2) }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel rename")
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now()+0.05) { folderNameFocused = true } }
    }
    private func favoriteButton(_ folder: Folder) -> some View {
        Button {
            withAnimation(.easeInOut(duration:0.25)) { folder.isFavorited.toggle(); folder.updateModifiedDate() }
        } label: {
            Image(systemName: folder.isFavorited ? "star.fill" : "star")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(folder.isFavorited ? "Unfavorite folder" : "Favorite folder")
    }
    private func folderMenu(_ folder: Folder) -> some View {
        Menu {
            Button("Rename") { renamingFolder = folder }
            Divider()
            Button(role: .destructive) { deleteFolder(folder) } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption2)
                .padding(.horizontal, 2)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
    private func commitRename(_ folder: Folder) {
        HapticManager.shared.buttonTapped()
        folder.updateModifiedDate()
        withAnimation(.easeInOut(duration:0.2)) { renamingFolder = nil; folderNameFocused = false }
    }
    private func cancelRename() {
        withAnimation(.easeInOut(duration:0.2)) { renamingFolder = nil; folderNameFocused = false }
    }

    private var folderSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Folders", systemImage: "folder").font(.caption).foregroundStyle(.secondary)
                Button(action: { withAnimation(.spring(response:0.35,dampingFraction:0.85)) { foldersCollapsed.toggle() } }) {
                    Image(systemName: foldersCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                if selectionMode && !selectedNoteIDs.isEmpty {
                    Button("Move Selected") { showingMoveSheet = true }
                        .font(.caption2)
                        .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, foldersCollapsed ? 4 : 0)
            if !foldersCollapsed { folderBar.transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }
    
    private var filteredNotes: [Note] { let base = allNotes.filter { !$0.isArchived }; return selectedFolder == nil ? base : base.filter { $0.folder?.id == selectedFolder?.id } }
    // Batch action bar
    private var batchActionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedNoteIDs.count) selected").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button { batchToggleFavorite() } label: { Label("Fav", systemImage: "star") }.buttonStyle(.borderless)
            Button { showingMoveSheet = true } label: { Label("Move", systemImage: "folder") }.buttonStyle(.borderless)
            Button(role: .destructive) { batchDelete() } label: { Label("Del", systemImage: "trash") }.buttonStyle(.borderless)
            Divider().frame(height: 16)
            Button { clearSelection() } label: { Text("Clear") }.buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .shadow(radius: 3, y: 2)
    }
    // select-all removed per updated requirements
    // MARK: - Actions & Helpers
    private func setupViewModels() {
        if notesViewModel == nil { notesViewModel = NotesViewModel(modelContext: modelContext) }
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
        _ = viewModel.createFolder()
    }
    private func deleteNote(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        withAnimation(.easeInOut(duration: 0.3)) { viewModel.deleteNote(note) }
    }
    private func toggleFavorite(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleNoteFavorite(note) }
        HapticManager.shared.buttonTapped()
    }
    private func deleteFolder(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        withAnimation(.easeInOut(duration: 0.3)) { viewModel.deleteFolder(folder) }
    }
    private func toggleFolderFavorite(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleFolderFavorite(folder) }
        HapticManager.shared.buttonTapped()
    }
    // MARK: - Multi-select helpers
    private func toggleSelect(_ note: Note) {
        if !selectionMode { selectionMode = true }
        if selectedNoteIDs.contains(note.id) { selectedNoteIDs.remove(note.id) } else { selectedNoteIDs.insert(note.id) }
        if selectedNoteIDs.isEmpty { selectionMode = false }
    }
    private func clearSelection() { withAnimation { selectedNoteIDs.removeAll(); selectionMode = false } }
    private func batchToggleFavorite() {
        guard let viewModel = notesViewModel else { return }
        let selected = allNotes.filter { selectedNoteIDs.contains($0.id) }
        let allFav = selected.allSatisfy { $0.isFavorited }
        withAnimation { selected.forEach { note in if allFav { note.isFavorited = false } else { note.isFavorited = true }; note.updateModifiedDate() } }
        viewModel.persistChanges()
    }
    private func batchDelete() {
        guard let viewModel = notesViewModel else { return }
        withAnimation { allNotes.filter { selectedNoteIDs.contains($0.id) }.forEach { viewModel.deleteNote($0) } }
        clearSelection()
    }
    private func batchMove(to folder: Folder?) {
        guard let viewModel = notesViewModel else { return }
        let selected = allNotes.filter { selectedNoteIDs.contains($0.id) }
        withAnimation { selected.forEach { note in note.folder = folder; note.updateModifiedDate() } }
        viewModel.persistChanges()
        clearSelection()
    }
    private func handleDrop(providers: [NSItemProvider], into folder: Folder) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let idString = String(data: data, encoding: .utf8), let uuid = UUID(uuidString: idString) {
                        DispatchQueue.main.async {
                            if let note = allNotes.first(where: { $0.id == uuid }) {
                                note.folder = folder
                                note.updateModifiedDate()
                                notesViewModel?.persistChanges()
                            }
                        }
                    } else if let str = item as? String, let uuid = UUID(uuidString: str) {
                        DispatchQueue.main.async {
                            if let note = allNotes.first(where: { $0.id == uuid }) {
                                note.folder = folder
                                note.updateModifiedDate()
                                notesViewModel?.persistChanges()
                            }
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    private var moveSheet: some View {
        NavigationStack {
            List {
                Section("Move to") {
                    Button("No Folder") { batchMove(to: nil); showingMoveSheet = false }
                    ForEach(folders) { folder in
                        Button(folder.name) { batchMove(to: folder); showingMoveSheet = false }
                    }
                }
            }
            .navigationTitle("Move Notes")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingMoveSheet = false } } }
        }
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

#Preview {
    SpatialTabView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}
