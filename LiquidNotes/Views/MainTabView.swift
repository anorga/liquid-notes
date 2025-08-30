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
                Tab("Notes", systemImage: "note.text", value: 0) {
                    SpatialTabView()
                }
                
                Tab("Favorites", systemImage: "star.fill", value: 1) {
                    PinnedNotesView()
                }
                
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                    SearchView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
            .onAppear {
                setupGlassTabBar()
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: handleAddAction) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(14)
                    }
                    .interactiveGlassButton()
                    .padding(.trailing, 20)
                    .padding(.top, 20)
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
        showingAddOptions = true
        HapticManager.shared.buttonTapped()
    }
    
    private func setupGlassTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
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
        
        if #available(iOS 17.0, *) {
            UITabBar.appearance().barTintColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
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