import SwiftUI
import SwiftData

struct DebugDataInspector: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdDate, order: .reverse) private var notes: [Note]
    @State private var log: [String] = []
    @State private var showRaw = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Notes", value: String(notes.count))
                }
                if showRaw {
                    Section("Raw Notes") {
                        ForEach(notes, id: \.id) { n in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(n.title.isEmpty ? "(Untitled)" : n.title).font(.headline)
                                Text(n.id.uuidString.prefix(8)).font(.caption2).foregroundStyle(.secondary)
                                Text("Archived: \(n.isArchived ? "Yes" : "No")  Favorited: \(n.isFavorited ? "Yes" : "No")").font(.caption)
                            }
                        }
                    }
                }
                if !log.isEmpty {
                    Section("Log") {
                        ForEach(Array(log.enumerated()), id: \.0) { _, line in
                            Text(line).font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Debug Store")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(showRaw ? "Hide Raw" : "Show Raw") { showRaw.toggle() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Validate") { validate() }
                }
            }
        }
    }
    
    private func validate() {
        do {
            let fetched = try modelContext.fetch(FetchDescriptor<Note>())
            log.append("Validate: fetched = \(fetched.count) at \(Date().description(with: .current))")
        } catch {
            log.append("Error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    DebugDataInspector()
        .modelContainer(for: [Note.self], inMemory: true)
}
