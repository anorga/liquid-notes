import AppIntents
import Foundation
import WidgetKit

struct ToggleFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Favorite"
    static var description = IntentDescription("Toggle the favorite status of a note")
    
    @Parameter(title: "Note ID")
    var noteID: String
    
    init() {}
    
    init(noteID: String) {
        self.noteID = noteID
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct OpenNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Note"
    static var description = IntentDescription("Open a specific note in the app")
    
    @Parameter(title: "Note ID")
    var noteID: String
    
    init() {}
    
    init(noteID: String) {
        self.noteID = noteID
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Task"
    static var description = IntentDescription("Add a quick task to a note")
    
    @Parameter(title: "Note ID")
    var noteID: String
    
    init() {}
    
    init(noteID: String) {
        self.noteID = noteID
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct MarkTaskCompleteIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark a task as complete from widget")
    
    @Parameter(title: "Note ID")
    var noteID: String
    
    @Parameter(title: "Task Index")
    var taskIndex: Int
    
    init() {}
    
    init(noteID: String, taskIndex: Int) {
        self.noteID = noteID
        self.taskIndex = taskIndex
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}