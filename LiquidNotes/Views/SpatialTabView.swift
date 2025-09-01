import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

struct SpatialTabView: View {
    @Environment(\.modelContext) private var modelContext
    // Order notes by creation time ascending so earliest appears top-left and new notes append to the right
    @Query(sort: \Note.createdDate, order: .forward) private var allNotes: [Note]
    @Query private var folders: [Folder]
    
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    // Multi-select state
    @State private var selectionMode: Bool = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var showingMoveSheet: Bool = false
    @State private var moveTargetFolder: Folder? = nil
    @State private var movingSingleNote: Note? = nil
    @AppStorage("foldersCollapsed") private var foldersCollapsed: Bool = false
    @State private var batchActionAnimating: Bool = false
    @State private var dropHoverFolderID: UUID? = nil
    // Archived inline option removed; filters always visible
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                VStack(alignment: .leading, spacing: 0) {
                    LNHeader(title: "Notes", subtitle: "\(allNotes.filter{ !$0.isArchived && !$0.isSystem }.count) active") { EmptyView() }
                    folderSection
                    // Slight upward pull to reduce vertical gap before first note row
                    Divider().opacity(0) // keeps layout stable
                        .padding(.top, -4)
                    
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
                            onToggleSelect: { note in toggleSelect(note) },
                            topContentInset: 12
                        )
                    }
                }
                .overlay(alignment: .bottom) { if selectionMode { batchActionBar.transition(.move(edge: .bottom).combined(with: .opacity)) } }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupViewModels()
                NotificationCenter.default.addObserver(forName: .requestMoveSingleNote, object: nil, queue: .main) { noteObj in
                    if let note = noteObj.object as? Note {
                        movingSingleNote = note
                        showingMoveSheet = true
                    }
                }
                // Ensure at least one default folder exists
                if folders.isEmpty, let vm = notesViewModel {
                    let created = vm.createFolder(name: "Folder")
                    // Immediately bind selection to the newly created default
                    selectedFolder = created
                }
                // Normalize any legacy default names
                var renamedAny = false
                folders.filter { $0.name == "New Folder" }.forEach { legacy in
                    legacy.name = "Folder"
                    legacy.updateModifiedDate()
                    renamedAny = true
                }
                if renamedAny { notesViewModel?.persistChanges() }
                // Ensure we have a selection (default to first ordered folder)
                ensureFolderSelection()
            }
            .onChange(of: folders) { ensureFolderSelection() }
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
                if orderedFolders.isEmpty {
                    // No folders yet (very first launch) – allow creating one
                    Button { createNewFolder() } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }.buttonStyle(.plain)
                } else {
                    // Always show every folder as full chip (including first)
                    ForEach(orderedFolders) { folder in folderChip(folder) }
                    // Persistent + button
                    Button { createNewFolder() } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }
    // Selected folder now externally bindable so other creation entry points (FAB, Quick Capture, Commands) honor current folder
    @Binding var selectedFolder: Folder?

    // Custom init providing a default binding (nil) for existing call sites
    init(selectedFolder: Binding<Folder?> = .constant(nil)) {
        self._selectedFolder = selectedFolder
    }
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
    
    // Notes already fetched in createdDate ascending order; just filter by folder/archive here.
    private var filteredNotes: [Note] {
        let base = allNotes.filter { !$0.isArchived && !$0.isSystem }
        return selectedFolder == nil ? base : base.filter { $0.folder?.id == selectedFolder?.id }
    }

    // Ordered folders: favorites first (creation order via zIndex), then others (creation order)
    private var orderedFolders: [Folder] {
        let fav = folders.filter { $0.isFavorited }.sorted { $0.zIndex < $1.zIndex }
        let non = folders.filter { !$0.isFavorited }.sorted { $0.zIndex < $1.zIndex }
        return fav + non
    }
    // Batch action bar
    private var batchActionBar: some View {
        HStack(spacing: 14) {
            Text("\(selectedNoteIDs.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Button { batchToggleFavorite() } label: {
                Image(systemName: "star")
                    .font(.system(size: 16, weight: .semibold))
            }
            .accessibilityLabel("Toggle favorite on selected")
            .buttonStyle(.borderless)
            Button { showingMoveSheet = true } label: {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .semibold))
            }
            .accessibilityLabel("Move selected")
            .buttonStyle(.borderless)
            Button(role: .destructive) { batchDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
            }
            .accessibilityLabel("Delete selected")
            .buttonStyle(.borderless)
            Divider().frame(height: 18)
            Button { clearSelection() } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 15, weight: .semibold))
            }
            .accessibilityLabel("Clear selection")
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
        )
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.2), value: selectedNoteIDs.count)
    }
    // select-all removed per updated requirements
    // MARK: - Actions & Helpers
    private func setupViewModels() {
        if notesViewModel == nil { notesViewModel = NotesViewModel(modelContext: modelContext) }
    }
    private func createNewNote() {
        HapticManager.shared.noteCreated()
        guard let viewModel = notesViewModel else { return }
    let newNote = viewModel.createNote(in: selectedFolder)
    // If no folder was selected (e.g. just created default implicitly), bind to note's folder
    if selectedFolder == nil, let f = newNote.folder { selectedFolder = f }
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
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) { viewModel.deleteNote(note) }
        }
    }
    private func toggleFavorite(_ note: Note) {
        guard let viewModel = notesViewModel else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleNoteFavorite(note) }
            HapticManager.shared.buttonTapped()
        }
    }
    private func deleteFolder(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        // Disallow deleting the final remaining folder to avoid churn / auto recreation.
        if folders.count <= 1 { 
            HapticManager.shared.buttonTapped() // subtle feedback for ignored action
            return 
        }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) { viewModel.deleteFolder(folder) }
            // If deletion removed the last folder, ensure a default is present and adopt it.
            if folders.isEmpty {
                if let newDefault = viewModel.ensureDefaultFolderAndReassignOrphans() {
                    selectedFolder = newDefault
                }
            } else {
                // If current selection was this folder, clear so ensureFolderSelection() will pick another
                if selectedFolder?.id == folder.id { selectedFolder = nil; ensureFolderSelection() }
            }
        }
    }
    private func toggleFolderFavorite(_ folder: Folder) {
        guard let viewModel = notesViewModel else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleFolderFavorite(folder) }
            HapticManager.shared.buttonTapped()
        }
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
        DispatchQueue.main.async {
            withAnimation {
                selected.forEach { note in
                    if allFav { note.isFavorited = false } else { note.isFavorited = true }
                    note.updateModifiedDate()
                }
            }
            viewModel.persistChanges()
        }
    }
    private func batchDelete() {
        guard let viewModel = notesViewModel else { return }
        DispatchQueue.main.async {
            withAnimation { allNotes.filter { selectedNoteIDs.contains($0.id) }.forEach { viewModel.deleteNote($0) } }
            clearSelection()
        }
    }
    private func batchMove(to folder: Folder?) {
        guard let viewModel = notesViewModel else { return }
        let selected = allNotes.filter { selectedNoteIDs.contains($0.id) }
        ModelMutationScheduler.shared.schedule {
            withAnimation { selected.forEach { note in note.folder = folder; note.updateModifiedDate() } }
            viewModel.persistChanges()
            DispatchQueue.main.async { clearSelection() }
        }
    }
    private func moveSingle(note: Note, to folder: Folder?) {
        guard let viewModel = notesViewModel else { return }
        ModelMutationScheduler.shared.schedule {
            withAnimation { note.folder = folder; note.updateModifiedDate() }
            viewModel.persistChanges()
        }
    }
    private func ensureFolderSelection() {
        // If current selection is nil or the selected folder was deleted, choose the first ordered folder (if any)
        if let current = selectedFolder, folders.contains(where: { $0.id == current.id }) {
            return // still valid
        }
        if selectedFolder == nil || !folders.contains(where: { $0.id == selectedFolder?.id }) {
            if let first = orderedFolders.first { selectedFolder = first }
        }
    }
    private func handleDrop(providers: [NSItemProvider], into folder: Folder) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let idString = String(data: data, encoding: .utf8), let uuid = UUID(uuidString: idString) {
                        DispatchQueue.main.async {
                            if let note = allNotes.first(where: { $0.id == uuid }) {
                                ModelMutationScheduler.shared.schedule {
                                    note.folder = folder
                                    note.updateModifiedDate()
                                    notesViewModel?.persistChanges()
                                }
                            }
                        }
                    } else if let str = item as? String, let uuid = UUID(uuidString: str) {
                        DispatchQueue.main.async {
                            if let note = allNotes.first(where: { $0.id == uuid }) {
                                ModelMutationScheduler.shared.schedule {
                                    note.folder = folder
                                    note.updateModifiedDate()
                                    notesViewModel?.persistChanges()
                                }
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
                    if movingSingleNote != nil {
                        Button("No Folder") { moveSingle(note: movingSingleNote!, to: nil); showingMoveSheet = false; movingSingleNote = nil }
                        ForEach(folders) { folder in
                            Button(folder.name) { moveSingle(note: movingSingleNote!, to: folder); showingMoveSheet = false; movingSingleNote = nil }
                        }
                    } else {
                        Button("No Folder") { batchMove(to: nil); showingMoveSheet = false }
                        ForEach(folders) { folder in
                            Button(folder.name) { batchMove(to: folder); showingMoveSheet = false }
                        }
                    }
                }
            }
            .navigationTitle(movingSingleNote == nil ? "Move Notes" : "Move Note")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingMoveSheet = false; movingSingleNote = nil } } }
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
    struct PreviewWrapper: View {
        @State private var selected: Folder? = nil
        var body: some View {
            SpatialTabView(selectedFolder: $selected)
                .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
        }
    }
    return PreviewWrapper()
}

extension Notification.Name {
    static let requestMoveSingleNote = Notification.Name("requestMoveSingleNote")
}
