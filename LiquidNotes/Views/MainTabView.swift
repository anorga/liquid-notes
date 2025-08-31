//
//  MainTabView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/18/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CommandTrigger.self) private var commandTrigger
    @State private var selectedTab = 0
    @State private var selectedFolder: Folder? = nil // shared across entry points
    @State private var showingQuickCapture = false // quick note
    @State private var showingQuickTaskCapture = false // single task capture
    @State private var quickTasksNoteID: UUID? = nil // cached reference
    @State private var showingCommandPalette = false
    @State private var showingDailyReview = false
    @State private var openNoteObserver: NSObjectProtocol?
    @State private var createAndLinkObserver: NSObjectProtocol?
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingSettings = false
    // Removed quick theme overlay per simplification feedback
    
    var body: some View {
    ZStack(alignment: .center) {
            TabView(selection: $selectedTab) {
                Tab("Notes", systemImage: "note.text", value: 0) { SpatialTabView(selectedFolder: $selectedFolder) }
                Tab("Favorites", systemImage: "star.fill", value: 1) { PinnedNotesView() }
                Tab("Tasks", systemImage: "checklist", value: 4) { TasksRollupView() }
                Tab("More", systemImage: "ellipsis", value: 5) { MoreView() }
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) { SearchView() }
            }
            .applyAdaptiveTabStyle()
            .background(
                // Glass backdrop for iPhone where system tab bar may appear plain
                Group {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        GeometryReader { proxy in
                            VStack { Spacer() }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .background(Color.clear)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .glassTabBar()
                                        .frame(height: 72)
                                        .allowsHitTesting(false)
                                }
                        }
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
            )
            .onAppear { setupGlassTabBar() }
            
            if selectedTab == 0 || selectedTab == 1 { // Only Notes & Favorites
                creationMenu
            }
        } // ZStack
        .onAppear { setupViewModel() }
    .onAppear { registerOpenNoteObserver() }
    .onAppear { registerCreateAndLinkObserver() }
    .onDisappear { if let obs = openNoteObserver { NotificationCenter.default.removeObserver(obs) } }
    .onDisappear { if let obs = createAndLinkObserver { NotificationCenter.default.removeObserver(obs) } }
    .onChange(of: commandTrigger.openPalette) { _, v in if v { showingCommandPalette = true; commandTrigger.openPalette = false } }
    .onChange(of: commandTrigger.newQuickNote) { _, v in if v { showingQuickCapture = true; commandTrigger.newQuickNote = false } }
    .onChange(of: commandTrigger.newFullNote) { _, v in if v { createNewNote(); commandTrigger.newFullNote = false } }
    .onChange(of: commandTrigger.openDailyReview) { _, v in if v { showingDailyReview = true; commandTrigger.openDailyReview = false } }
    // Removed reindex trigger (simplification)
        .sheet(item: $selectedNote) { note in
            NoteEditorView(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingQuickCapture) {
            QuickCaptureView { title, body, tags in
                guard let vm = notesViewModel else { return }
                let note = vm.createNote(in: selectedFolder, title: title, content: body)
                tags.forEach { note.addTag($0) }
                note.updateLinkedNoteTitles()
                selectedNote = note // optionally jump into full editor
            }
            .presentationDetents([.fraction(0.38), .medium])
        }
        .sheet(isPresented: $showingDailyReview) {
            DailyReviewView()
        }
        .sheet(isPresented: $showingQuickTaskCapture) {
            QuickTaskCaptureView { taskText in
                guard let vm = notesViewModel else { return }
                let target = fetchOrCreateQuickTasksNote(using: vm)
                target.addTask(taskText)
                try? modelContext.save()
                HapticManager.shared.success()
            }
            .presentationDetents([.fraction(0.25)])
        }
        .sheet(isPresented: $showingCommandPalette) {
            CommandPaletteView(
                onSelect: handleCommand
            )
            .presentationDetents([.fraction(0.4), .large])
        }
    }
    
    // MARK: - Native Creation Menu
    private var creationMenu: some View {
        Menu {
            Button { HapticManager.shared.noteCreated(); createNewNote() } label: { Label("New Note", systemImage: "doc.badge.plus") }
            Button { HapticManager.shared.buttonTapped(); showingQuickTaskCapture = true } label: { Label("Quick Task", systemImage: "checklist") }
            if selectedTab == 0 { // Only on Notes tab
                Button { HapticManager.shared.buttonTapped(); createNewFolder() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
            }
            Divider()
            Button { HapticManager.shared.buttonTapped(); showingDailyReview = true } label: { Label("Daily Review", systemImage: "calendar") }
            Button { HapticManager.shared.buttonTapped(); showingCommandPalette = true } label: { Label("Commands", systemImage: "command") }
            // Reindex removed
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .padding(14)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .contentShape(Circle())
        }
        .menuActionDismissBehavior(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 16)
        .padding(.top, 12)
        .accessibilityLabel("Create")
    }
    
    private func setupGlassTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        if #available(iOS 15.0, *) {
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        appearance.backgroundColor = UIColor.clear
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    UITabBar.appearance().clipsToBounds = false
    UITabBar.appearance().isTranslucent = true
        
        if #available(iOS 17.0, *) {
            UITabBar.appearance().barTintColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
    }
    
    private func setupViewModel() {
        if notesViewModel == nil {
            notesViewModel = NotesViewModel(modelContext: modelContext)
        }
        // Auto-select first folder if none selected (so new notes default correctly)
        if selectedFolder == nil {
            let folderDescriptor = FetchDescriptor<Folder>()
            if let folders = try? modelContext.fetch(folderDescriptor), let first = folders.first {
                selectedFolder = first
            }
        }
    }
    
    private func createNewNote() {
        HapticManager.shared.noteCreated()
    guard let viewModel = notesViewModel else { return }
    let newNote = viewModel.createNote(in: selectedFolder)
        do {
            try modelContext.save()
        } catch {
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedNote = newNote
        }
    }
    
    private func createNewFolder() {
        HapticManager.shared.buttonTapped()
        
        guard let viewModel = notesViewModel else { return }
    let created = viewModel.createFolder()
    // If no selection yet, or user is on default nil selection, switch to the newly created folder
    if selectedFolder == nil { selectedFolder = created }
    }
}

// MARK: - Command Handling
private extension MainTabView {
    func handleCommand(_ command: CommandPaletteView.Command) {
    let analytics = AnalyticsManager.shared
        switch command {
    case .newQuickNote: showingQuickCapture = true; analytics.increment("cmd.quickNote")
    case .newFullNote: createNewNote(); analytics.increment("cmd.fullNote")
    case .dailyReview: showingDailyReview = true; analytics.increment("cmd.dailyReview")
    // reindexLinks removed
    case .openSearch: selectedTab = 2; analytics.increment("cmd.openSearch")
    case .openTasks: selectedTab = 4; analytics.increment("cmd.openTasks")
    case .toggleFocus:
        NotificationCenter.default.post(name: .lnToggleFocusMode, object: nil)
        analytics.increment("cmd.toggleFocus")
    case .newTemplate:
        createNewNote()
        NotificationCenter.default.post(name: .lnInsertTemplate, object: nil)
        analytics.increment("cmd.newTemplate")
        }
    }
}

// MARK: - Command Palette View
struct CommandPaletteView: View {
    enum Command: String, CaseIterable, Identifiable { case newQuickNote, newFullNote, dailyReview, openSearch, openTasks, toggleFocus, newTemplate; var id: String { rawValue } }
    let onSelect: (Command) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var filtered: [Command] { if query.isEmpty { return Command.allCases } else { return Command.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(query) } } }
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                VStack(spacing: 0) {
                    LNHeader(title: "Commands") { EmptyView() }
                    VStack(spacing: 14) {
                        TextField("Type a command…", text: $query)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.elevated, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                        List(filtered) { cmd in
                            Button(action: { onSelect(cmd); dismiss() }) {
                                HStack {
                                    Text(label(cmd)).font(.body)
                                    Spacer()
                                    Text(shortcut(cmd)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .navigationBarHidden(true)
        }
    }
    private func label(_ c: Command) -> String {
    switch c { case .newQuickNote: return "New Quick Note"; case .newFullNote: return "New Full Note"; case .dailyReview: return "Open Daily Review"; case .openSearch: return "Go to Search"; case .openTasks: return "Go to Tasks"; case .toggleFocus: return "Toggle Focus Mode"; case .newTemplate: return "New Structured Note" }
    }
    private func shortcut(_ c: Command) -> String { "" }
}

// MARK: - Notification Handling
extension Notification.Name { static let lnOpenNoteRequested = Notification.Name("lnOpenNoteRequested") }
extension Notification.Name { static let lnCreateAndLinkNoteRequested = Notification.Name("lnCreateAndLinkNoteRequested") }
extension Notification.Name { static let lnToggleFocusMode = Notification.Name("lnToggleFocusMode") }
extension Notification.Name { static let lnInsertTemplate = Notification.Name("lnInsertTemplate") }

private extension MainTabView {
    func registerOpenNoteObserver() {
        openNoteObserver = NotificationCenter.default.addObserver(forName: .lnOpenNoteRequested, object: nil, queue: .main) { notif in
            guard let id = notif.object as? UUID else { return }
            // Find note and present
            let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
            if let note = try? modelContext.fetch(descriptor).first {
                selectedNote = note
            }
        }
    }
    func registerCreateAndLinkObserver() {
        createAndLinkObserver = NotificationCenter.default.addObserver(forName: .lnCreateAndLinkNoteRequested, object: nil, queue: .main) { notif in
            guard let title = notif.object as? String else { return }
            if notesViewModel == nil { setupViewModel() }
            guard let vm = notesViewModel else { return }
            Task { @MainActor in
                let new = vm.createNote(in: selectedFolder, title: title, content: "")
                // reindex removed
                selectedNote = new
            }
        }
    }
}

// MARK: - Quick Capture Sheet
struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String, [String]) -> Void
    @State private var title: String = ""
    // Renamed from `body` to avoid clashing with the computed View `body`
    @State private var noteBody: String = ""
    @State private var tagsText: String = ""
    @State private var isSaving = false
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    LNHeader(title: "Quick Capture") { EmptyView() }
                    VStack(spacing: 16) {
                        TextField("Title", text: $title)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                        TextField("Quick note…", text: $noteBody, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                        TextField("Tags (comma)", text: $tagsText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                        Spacer(minLength: 0)
                        HStack {
                            Button("Cancel") { dismiss() }
                                .buttonStyle(.borderless)
                            Spacer()
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                let tagList = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                onSave(title, noteBody, tagList)
                                HapticManager.shared.success()
                                dismiss()
                            } label: {
                                Text("Save")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 22).padding(.vertical, 12)
                                    .background(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                            }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity((title.isEmpty && noteBody.isEmpty) ? 0.4 : 1)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Quick Task Capture Sheet
struct QuickTaskCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var taskText: String = ""
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    // Header removed per simplification request
                    VStack(spacing: 16) {
                        TextField("Task description", text: $taskText, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                        Spacer(minLength: 0)
                        HStack {
                            Button("Cancel") { dismiss() }
                                .buttonStyle(.borderless)
                            Spacer()
                            Button {
                                let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onSave(trimmed)
                                dismiss()
                            } label: {
                                Text("Add Task")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                            }
                            .disabled(taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Quick Tasks Helper
private extension MainTabView {
    func fetchOrCreateQuickTasksNote(using vm: NotesViewModel) -> Note {
        if let existingID = quickTasksNoteID {
            let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == existingID })
            if let found = try? modelContext.fetch(descriptor).first { return found }
        }
        // Search by reserved title
        let title = "Quick Tasks"
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.title == title })
        if let found = try? modelContext.fetch(descriptor).first {
            quickTasksNoteID = found.id
            return found
        }
        // Create hidden aggregation note
    let new = vm.createNote(in: selectedFolder, title: title, content: "")
    new.isFavorited = false
    new.isSystem = true
        quickTasksNoteID = new.id
        try? modelContext.save()
        return new
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}

// MARK: - Adaptive Tab Style
private extension View {
    @ViewBuilder func applyAdaptiveTabStyle() -> some View {
    // Always use standard tab style (feedback: no sidebar menu on iPad)
    self
    }
}