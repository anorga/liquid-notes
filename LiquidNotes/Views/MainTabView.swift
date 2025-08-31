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
    @State private var showingSettings = false
    // Removed quick theme overlay per simplification feedback
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                Tab("Notes", systemImage: "note.text", value: 0) { SpatialTabView() }
                
                Tab("Favorites", systemImage: "star.fill", value: 1) { PinnedNotesView() }
                
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) { SearchView() }
                
                Tab("Settings", systemImage: "gearshape.fill", value: 3) { SettingsView() }
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
                Button(action: { handleAddAction() }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(14)
                }
                .interactiveGlassButton()
                .padding(.trailing, 20)
                .padding(.top, 20)
                .transition(.opacity.combined(with: .scale))
            }
        } // ZStack
        .onAppear { setupViewModel() }
        .confirmationDialog("Create New", isPresented: $showingAddOptions, titleVisibility: .visible) {
            Button("Note", action: createNewNote)
            Button("Folder", action: createNewFolder)
            Button("Cancel", role: .cancel) { }
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
    }
    
    private func createNewNote() {
        HapticManager.shared.noteCreated()
    guard let viewModel = notesViewModel else { return }
        let newNote = viewModel.createNote()
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
        let _ = viewModel.createFolder()
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