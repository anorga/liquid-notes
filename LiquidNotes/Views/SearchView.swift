//
//  SearchView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/18/25.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Very dark blue and orange gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.8), location: 0.0),
                        .init(color: Color.orange.opacity(0.6), location: 0.5),
                        .init(color: Color(red: 0.0, green: 0.35, blue: 0.7).opacity(0.85), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                // Search field - starts unfocused for discovery
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search notes...", text: $searchText)
                            .textFieldStyle(.plain)
                            .onTapGesture {
                                isSearching = true
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    if !isSearching && searchText.isEmpty {
                        // Discovery content when not searching
                        DiscoveryContent()
                    }
                }
                
                if isSearching || !searchText.isEmpty {
                    // Search results
                    SearchResults(searchText: searchText, notes: allNotes)
                }
                
                Spacer()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct DiscoveryContent: View {
    var body: some View {
        VStack(spacing: 24) {
            // Search suggestions
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                    Text("Quick Search")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    SearchSuggestionCard(icon: "pin.fill", title: "Pinned", subtitle: "Your pinned notes")
                    SearchSuggestionCard(icon: "calendar", title: "Recent", subtitle: "Last 7 days")
                    SearchSuggestionCard(icon: "tag", title: "Tags", subtitle: "Browse by tag")
                    SearchSuggestionCard(icon: "archivebox", title: "Archived", subtitle: "Old notes")
                }
            }
            .padding(.horizontal)
            
            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.secondary)
                    Text("Search Tips")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    SearchTip(text: "Search by title, content, or tags")
                    SearchTip(text: "Use quotes for exact phrases")
                    SearchTip(text: "Search works across all your notes")
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct SearchSuggestionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SearchTip: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct SearchResults: View {
    let searchText: String
    let notes: [Note]
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return []
        }
        
        return notes.filter { note in
            !note.isArchived &&
            (note.title.localizedCaseInsensitiveContains(searchText) ||
             note.content.localizedCaseInsensitiveContains(searchText) ||
             note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    var body: some View {
        VStack {
            if filteredNotes.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    Text("Try different keywords")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List(filteredNotes, id: \.id) { note in
                    SearchResultRow(note: note, searchText: searchText)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct SearchResultRow: View {
    let note: Note
    let searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            HStack {
                Text(note.modifiedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SearchView()
        .modelContainer(DataContainer.previewContainer)
}