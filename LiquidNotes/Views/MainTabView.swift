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
    @State private var showingAddOptions = false
    @State private var notesViewModel: NotesViewModel?
    @State private var selectedNote: Note?
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Notes Tab (spatial canvas view) - Default view
                Tab("Notes", systemImage: "note.text", value: 0) {
                    SpatialTabView()
                }
                
                // Favorites Tab  
                Tab("Favorites", systemImage: "star.fill", value: 1) {
                    PinnedNotesView()
                }
                
                // Search Tab with native trailing placement
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                    SearchView()
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: handleAddAction) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(12)
                    }
                    .liquidGlassEffect(.regular, in: Circle())
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .confirmationDialog("Create New", isPresented: $showingAddOptions, titleVisibility: .hidden) {
            Button("Note", action: createNewNote)
            Button("Folder", action: createNewFolder)
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            setupViewModel()
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorView(note: note)
                .presentationDetents([.medium, .large])
        }
    }
    
    // iOS 26 native add action - consolidated from AddFloatingButton
    private func handleAddAction() {
        // Trigger the confirmation dialog for creating notes/folders
        showingAddOptions = true
        HapticManager.shared.buttonTapped()
    }
    
    private func setupViewModel() {
        if notesViewModel == nil {
            print("🔧 Setting up NotesViewModel with modelContext: \(modelContext)")
            notesViewModel = NotesViewModel(modelContext: modelContext)
            print("✅ NotesViewModel setup complete")
        }
    }
    
    private func createNewNote() {
        print("🚀 MainTabView: createNewNote called")
        HapticManager.shared.noteCreated()
        
        guard let viewModel = notesViewModel else { 
            print("❌ MainTabView: NotesViewModel is nil!")
            return 
        }
        
        print("📝 MainTabView: Creating note with viewModel")
        let newNote = viewModel.createNote()
        print("✅ MainTabView: Note created with ID: \(newNote.id)")
        
        // Add a small delay to ensure the note is properly saved before showing editor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📱 MainTabView: Setting selectedNote to show editor")
            self.selectedNote = newNote
        }
    }
    
    private func createNewFolder() {
        HapticManager.shared.buttonTapped()
        
        guard let viewModel = notesViewModel else { return }
        let _ = viewModel.createFolder()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}