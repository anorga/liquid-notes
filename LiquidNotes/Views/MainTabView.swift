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
    @State private var selectedTab = 0
    @State private var selectedFolder: Folder? = nil // shared across entry points
    @State private var showingQuickTaskCapture = false // single task capture
    @State private var quickTasksNoteID: UUID? = nil // cached reference
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
    // Command system removed
    // Removed reindex trigger (simplification)
        .sheet(item: $selectedNote) { note in
            NoteEditorView(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingDailyReview) {
            DailyReviewView()
        }
        .sheet(isPresented: $showingQuickTaskCapture) {
            QuickTaskCaptureView { taskText, due in
                guard let vm = notesViewModel else { return }
                let target = fetchOrCreateQuickTasksNote(using: vm)
                target.addTask(taskText, dueDate: due)
                try? modelContext.save()
                HapticManager.shared.success()
            }
            .presentationDetents([.fraction(0.3)])
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
        // If user deleted all folders previously, createNote(in:) will have auto-created
        // a default folder and assigned it to the new note. Adopt that folder as the
        // current selection so the note is visibly inside a folder context.
        if selectedFolder == nil, let autoFolder = newNote.folder {
            selectedFolder = autoFolder
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

// MARK: - Notification Handling
extension Notification.Name { static let lnOpenNoteRequested = Notification.Name("lnOpenNoteRequested") }
extension Notification.Name { static let lnCreateAndLinkNoteRequested = Notification.Name("lnCreateAndLinkNoteRequested") }

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


// MARK: - Quick Task Capture Sheet
struct QuickTaskCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Date?) -> Void
    @State private var taskText: String = ""
    @State private var dueDate: Date? = nil
    @State private var showingPicker = false
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 16) {
                        TextField("Task description", text: $taskText, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                        HStack(spacing: 12) {
                            if let d = dueDate {
                                Text("Due: \(d.ln_dayDistanceString())")
                                    .font(.caption2)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                                    .foregroundStyle(.orange)
                            }
                            Button { showingPicker = true } label: {
                                Image(systemName: dueDate == nil ? "calendar.badge.plus" : "calendar.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(dueDate == nil ? Color.secondary : Color.orange)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                        }
                        Spacer(minLength: 0)
                        HStack {
                            Button("Cancel") { dismiss() }
                                .buttonStyle(.borderless)
                            Spacer()
                            Button {
                                let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onSave(trimmed, dueDate)
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
        .sheet(isPresented: $showingPicker) {
            DueDateCalendarPicker(initialDate: dueDate) { selected in dueDate = selected }
                .presentationDetents([.medium])
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