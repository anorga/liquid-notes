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
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showThemeOverlay = false
    
    var body: some View {
    ZStack {
            TabView(selection: $selectedTab) {
                Tab("Notes", systemImage: "note.text", value: 0) { SpatialTabView() }
                
                Tab("Favorites", systemImage: "star.fill", value: 1) { PinnedNotesView() }
                
                Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) { SearchView() }
                
                Tab("Settings", systemImage: "gearshape.fill", value: 3) { SettingsView() }
            }
            .tabViewStyle(.sidebarAdaptable)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
            .onAppear {
                setupGlassTabBar()
            }
            
            VStack {
                HStack {
                    Spacer()
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
                }
                Spacer()
            }
        }
        .overlay(alignment: .center) {
            if showThemeOverlay {
                VStack(spacing: 16) {
                    Text("Quick Theme")
                        .font(.headline)
                    HStack(spacing: 10) {
                        ForEach(GlassTheme.allCases, id: \.self) { theme in
                            Circle()
                                .fill(LinearGradient(colors: theme.primaryGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(themeManager.currentTheme == theme ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    themeManager.applyTheme(theme)
                                    HapticManager.shared.buttonTapped()
                                }
                        }
                    }
                    Button("Close") { withAnimation(.spring()) { showThemeOverlay = false } }
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 20)
                .padding(40)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showThemeOverlay = true }
            HapticManager.shared.buttonTapped()
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