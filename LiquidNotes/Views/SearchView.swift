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
    
    @AppStorage("persistedSearchText") private var searchText = ""
    @State private var isSearching = false
    @State private var activeFilterSelection: Int = 0 // 0=Active 1=Archived 2=All
    @State private var selectedNote: Note?
    @FocusState private var searchFocused: Bool
    @AppStorage("recentSearchesRaw") private var recentSearchesRaw: String = "" // pipe-delimited
    @State private var debouncedQuery: String = ""
    @State private var debounceTask: DispatchWorkItem?

    // Derived recent searches array
    private var recentSearches: [String] {
        recentSearchesRaw.split(separator: "|").map { String($0) }.filter { !$0.isEmpty }
    }
    private func addRecentSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var set = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        // Insert new at front
        set.insert(trimmed, at: 0)
        // Deduplicate preserving first occurrence
        var seen: Set<String> = []
        set = set.filter { val in
            let lower = val.lowercased()
            if seen.contains(lower) { return false }
            seen.insert(lower)
            return true
        }
        if set.count > 8 { set = Array(set.prefix(8)) }
        recentSearchesRaw = set.joined(separator: "|")
    }
    private func removeRecent(_ term: String) {
        let remaining = recentSearches.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        recentSearchesRaw = remaining.joined(separator: "|")
    }
    private var topTags: [String] {
        let tags = allNotes.flatMap { $0.tags }
        var counts: [String:Int] = [:]
        for t in tags { counts[t, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    HStack {
                        Text("Search")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 18) {
                        // Search field
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search notes...", text: $searchText)
                                .textFieldStyle(.plain)
                                .focused($searchFocused)
                                .onTapGesture { isSearching = true }
                                .submitLabel(.search)
                                .onSubmit { addRecentSearch(searchText) }
                                .onChange(of: searchText) { _, newVal in
                                    debounceTask?.cancel()
                                    let trimmed = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmed.isEmpty { debouncedQuery = ""; return }
                                    let task = DispatchWorkItem { debouncedQuery = trimmed }
                                    debounceTask = task
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: task)
                                }
                            if !searchText.isEmpty {
                                Button {
                                    withAnimation(.easeInOut) {
                                        searchText = ""; isSearching = false; searchFocused = false; debouncedQuery = ""
                                    }
                                } label: { Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear search")
                            }
                            if searchFocused || isSearching {
                                Button("Cancel") {
                                    withAnimation(.easeInOut) { searchText = ""; isSearching = false; searchFocused = false; debouncedQuery = "" }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        if isSearching || !searchText.isEmpty {
                            // Filter chips
                            HStack(spacing: 8) {
                                SearchFilterChip(title: "Active", index: 0, selection: $activeFilterSelection)
                                SearchFilterChip(title: "Archived", index: 1, selection: $activeFilterSelection)
                                SearchFilterChip(title: "All", index: 2, selection: $activeFilterSelection)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))

                            // Recent searches
                            if !recentSearches.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recentSearches, id: \.self) { term in
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.12))
                                                .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 0.6))
                                                .overlay(Text(term).font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 5))
                                                .onTapGesture { withAnimation { searchText = term; debouncedQuery = term; isSearching = true; searchFocused = false } }
                                                .contextMenu { Button("Remove") { removeRecent(term) } }
                                        }
                                        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                            Button(action: { addRecentSearch(searchText) }) {
                                                Label("Save", systemImage: "plus").font(.caption2)
                                            }
                                            .buttonStyle(.borderless)
                                            .padding(.horizontal, 4)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .transition(.opacity)
                            }

                            // Top tag chips
                            if !topTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(topTags, id: \.self) { tag in
                                            Capsule()
                                                .fill(LinearGradient(colors: [Color.blue.opacity(0.25), Color.cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                                                .overlay(Text("#" + tag).font(.caption2).foregroundStyle(.primary).padding(.horizontal, 10).padding(.vertical, 5))
                                                .onTapGesture { withAnimation { searchText = tag; debouncedQuery = tag; isSearching = true; addRecentSearch(tag); searchFocused = false } }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .transition(.opacity)
                            }
                        }

                        if isSearching || !searchText.isEmpty {
                            SearchResults(
                                searchText: debouncedQuery,
                                notes: allNotes,
                                filterSelection: activeFilterSelection,
                                onOpen: { note in selectedNote = note }
                            )
                            .transition(.opacity)
                        } else {
                            DiscoveryContent()
                                .transition(.opacity)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .presentationDetents([.medium, .large])
            }
            .navigationBarHidden(true)
        }
    }
} // <-- Close struct SearchView here

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
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(DiscoverySuggestion.allCases) { suggestion in
                        SearchSuggestionCard(icon: suggestion.icon, title: suggestion.title, subtitle: suggestion.subtitle)
                    }
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

enum DiscoverySuggestion: CaseIterable, Identifiable {
    case favorites, recent, tags, archived
    var id: String { title }
    var icon: String {
        switch self { case .favorites: return "star.fill"; case .recent: return "calendar"; case .tags: return "tag"; case .archived: return "archivebox" }
    }
    var title: String {
        switch self { case .favorites: return "Favorites"; case .recent: return "Recent"; case .tags: return "Tags"; case .archived: return "Archived" }
    }
    var subtitle: String {
        switch self { case .favorites: return "Your favorite notes"; case .recent: return "Last 7 days"; case .tags: return "Browse by tag"; case .archived: return "Old notes" }
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
    let filterSelection: Int
    let onOpen: (Note) -> Void

    private var filteredNotes: [Note] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return notes.filter { note in
            // Filter by archive state
            switch filterSelection {
            case 0: if note.isArchived { return false }
            case 1: if !note.isArchived { return false }
            default: break
            }
            return (
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.tertiary)
                    Text("No results")
                        .font(.headline)
                    Text("Try different keywords")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredNotes, id: \.id) { note in
                            SearchResultRow(note: note, searchText: searchText)
                                .onTapGesture { onOpen(note) }
                                .padding(.horizontal, 20)
                        }
                        Spacer(minLength: 20)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: filteredNotes.count)
    }
}

private struct SearchFilterChip: View {
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

struct SearchResultRow: View {
    let note: Note
    let searchText: String
    @ObservedObject private var themeManager = ThemeManager.shared

    private func highlight(_ text: String) -> Text {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Text(text) }
        let lc = text.lowercased()
        let qlc = query.lowercased()
        var result = Text("")
        var idx = lc.startIndex
        while idx < lc.endIndex {
            if let range = lc[idx...].range(of: qlc) {
                let prefix = String(lc[idx..<range.lowerBound])
                if !prefix.isEmpty { result = result + Text(String(text[idx..<range.lowerBound])) }
                let match = String(text[range])
                result = result + Text(match).fontWeight(.semibold).foregroundStyle(themeManager.currentTheme.primaryGradient.first ?? .accentColor)
                idx = range.upperBound
            } else {
                let remainder = String(text[idx...])
                if !remainder.isEmpty { result = result + Text(remainder) }
                break
            }
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !note.title.isEmpty {
                    highlight(note.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if note.isFavorited {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            
            if !note.content.isEmpty {
                highlight(note.content)
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
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
    }
}
