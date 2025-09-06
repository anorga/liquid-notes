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
    @State private var showingDailyReview = false
    @State private var openNoteObserver: NSObjectProtocol?
    @State private var createAndLinkObserver: NSObjectProtocol?
    @State private var quickTaskObserver: NSObjectProtocol?
    @State private var openTasksObserver: NSObjectProtocol?
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    @State private var showingSettings = false
    // Removed quick theme overlay per simplification feedback
    
    var body: some View {
        // Build the core TabView once, then apply iOS-specific bar styling below
        let tabCore = TabView(selection: $selectedTab) {
            Tab("Notes", systemImage: "note.text", value: 0) { SpatialTabView(selectedFolder: $selectedFolder) }
            Tab("Favorites", systemImage: "star.fill", value: 1) { PinnedNotesView() }
            Tab("Tasks", systemImage: "checklist", value: 4) { TasksRollupView() }
            Tab("More", systemImage: "ellipsis", value: 5) { MoreView() }
            Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) { SearchView() }
        }
        .onAppear { setupViewModel() }
    .onAppear { registerOpenNoteObserver() }
    .onAppear { registerCreateAndLinkObserver() }
    .onAppear { registerQuickTaskObserver() }
    .onAppear { registerOpenTasksObserver() }
    .onDisappear { if let obs = openNoteObserver { NotificationCenter.default.removeObserver(obs) } }
    .onDisappear { if let obs = createAndLinkObserver { NotificationCenter.default.removeObserver(obs) } }
    .onDisappear { if let obs = quickTaskObserver { NotificationCenter.default.removeObserver(obs) } }
    .onDisappear { if let obs = openTasksObserver { NotificationCenter.default.removeObserver(obs) } }
    // Command system removed
    // Removed reindex trigger (simplification)
        .sheet(item: $selectedNote) { note in
            if UIDevice.current.userInterfaceIdiom == .pad {
                NoteEditorView(note: note)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            } else {
                NoteEditorView(note: note)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingDailyReview) {
            DailyReviewView()
        }
        .sheet(isPresented: $showingQuickTaskCapture) {
            QuickTaskCaptureView { taskText, due in
                // Create standalone task (not attached to a note)
                let task = TaskItem(text: taskText, isCompleted: false, note: nil, dueDate: due)
                modelContext.insert(task)
                try? modelContext.save()
                if task.dueDate != nil { SharedDataManager.shared.scheduleTaskNotification(for: task) }
                BadgeManager.shared.taskAdded()
                HapticManager.shared.success()
                SharedDataManager.shared.refreshStandaloneTasksWidgetData(context: modelContext)
            }
            .presentationDetents([.fraction(0.3)])
        }
        // Apply bar appearance conditionally to match iOS 26+ "glass" behavior
        Group {
            if #available(iOS 26.0, *) {
                tabCore
                    .toolbarBackground(.automatic, for: .tabBar)
                    .toolbarBackgroundVisibility(.automatic, for: .tabBar)
            } else {
                tabCore
                    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                    .toolbarBackgroundVisibility(.visible, for: .tabBar)
            }
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
    
    private func createNewFavoritedNote() {
        guard let viewModel = notesViewModel else { return }
        
        // Create new note and immediately mark it as favorited
        let newNote = viewModel.createNote(in: selectedFolder, title: "", content: "")
        newNote.isFavorited = true
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving favorited note: \(error)")
        }
        
        // If user deleted all folders previously, createNote(in:) will have auto-created
        // a default folder and assigned it to the new note. Adopt that folder as the
        // current selection so the note is visibly inside a folder context.
        if selectedFolder == nil, let autoFolder = newNote.folder {
            selectedFolder = autoFolder
        }
        
        // Open the note in the editor immediately
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
extension Notification.Name { static let lnNoteAttachmentsChanged = Notification.Name("lnNoteAttachmentsChanged") }
extension Notification.Name { static let showQuickTaskCapture = Notification.Name("showQuickTaskCapture") }
extension Notification.Name { static let openTasksTab = Notification.Name("openTasksTab") }
extension Notification.Name { static let focusTask = Notification.Name("focusTask") }

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
                selectedNote = new
            }
        }
    }
    
    func registerQuickTaskObserver() {
        quickTaskObserver = NotificationCenter.default.addObserver(forName: .showQuickTaskCapture, object: nil, queue: .main) { _ in
            showingQuickTaskCapture = true
        }
    }
    
    func registerOpenTasksObserver() {
        openTasksObserver = NotificationCenter.default.addObserver(forName: .openTasksTab, object: nil, queue: .main) { notif in
            selectedTab = 4 // Tasks tab index
            if let idStr = notif.object as? String, let uuid = UUID(uuidString: idStr) {
                NotificationCenter.default.post(name: .focusTask, object: uuid)
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

// (Quick Tasks helper removed — standalone tasks are now used.)

#Preview {
    MainTabView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}
