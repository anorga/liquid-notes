import AppIntents
import SwiftData
import SwiftUI

@available(iOS 18.0, *)
struct NoteEntity: AppEntity {
    var id: String
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Note")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title.isEmpty ? "Untitled Note" : title)")
    }

    static var defaultQuery = NoteEntityQuery()

    init(id: String, title: String, content: String, createdDate: Date, modifiedDate: Date) {
        self.id = id
        self.title = title
        self.content = content
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    init(from note: Note) {
        self.id = note.id.uuidString
        self.title = note.title
        self.content = note.previewExcerpt.isEmpty ? note.content : note.previewExcerpt
        self.createdDate = note.createdDate
        self.modifiedDate = note.modifiedDate
    }
}

@available(iOS 18.0, *)
struct NoteEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        let container = try ModelContainer(for: Note.self)
        let context = ModelContext(container)

        var results: [NoteEntity] = []
        for idString in identifiers {
            guard let uuid = UUID(uuidString: idString) else { continue }
            let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == uuid && !$0.isArchived && !$0.isSystem })
            if let notes = try? context.fetch(descriptor), let note = notes.first {
                results.append(NoteEntity(from: note))
            }
        }
        return results
    }

    func suggestedEntities() async throws -> [NoteEntity] {
        let container = try ModelContainer(for: Note.self)
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { !$0.isArchived && !$0.isSystem },
            sortBy: [SortDescriptor(\.modifiedDate, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        let notes = try context.fetch(descriptor)
        return notes.map { NoteEntity(from: $0) }
    }
}

@available(iOS 18.0, *)
struct CreateNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Note"
    static var description = IntentDescription("Create a new note in LiquidNotes")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Title")
    var noteTitle: String?

    @Parameter(title: "Content")
    var noteContent: String?

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let container = try ModelContainer(for: Note.self, NoteCategory.self, Folder.self, TaskItem.self)
        let context = ModelContext(container)

        let note = Note(title: noteTitle ?? "", content: noteContent ?? "")
        context.insert(note)
        try context.save()

        NotificationCenter.default.post(
            name: NSNotification.Name("OpenNoteFromIntent"),
            object: nil,
            userInfo: ["noteID": note.id.uuidString]
        )

        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenNoteAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Note"
    static var description = IntentDescription("Open a specific note in LiquidNotes")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Note")
    var note: NoteEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenNoteFromIntent"),
            object: nil,
            userInfo: ["noteID": note.id]
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct SearchNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Notes"
    static var description = IntentDescription("Search for notes in LiquidNotes")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Search Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        NotificationCenter.default.post(
            name: NSNotification.Name("SearchNotesFromIntent"),
            object: nil,
            userInfo: ["query": query]
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct ShowAllNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Show All Notes"
    static var description = IntentDescription("Open LiquidNotes and show all notes")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        return .result()
    }
}

@available(iOS 18.0, *)
struct ShowFavoriteNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Favorite Notes"
    static var description = IntentDescription("Show favorite notes in LiquidNotes")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowFavoritesFromIntent"),
            object: nil,
            userInfo: nil
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct LiquidNotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "New note in \(.applicationName)",
                "Make a note in \(.applicationName)",
                "Start a note in \(.applicationName)"
            ],
            shortTitle: "Create Note",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Search notes in \(.applicationName)",
                "Find notes in \(.applicationName)"
            ],
            shortTitle: "Search Notes",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: ShowAllNotesIntent(),
            phrases: [
                "Show my notes in \(.applicationName)",
                "Open \(.applicationName)",
                "Show all notes in \(.applicationName)"
            ],
            shortTitle: "Show Notes",
            systemImageName: "note.text"
        )

        AppShortcut(
            intent: ShowFavoriteNotesIntent(),
            phrases: [
                "Show favorite notes in \(.applicationName)",
                "Show starred notes in \(.applicationName)"
            ],
            shortTitle: "Favorite Notes",
            systemImageName: "star.fill"
        )
    }
}
