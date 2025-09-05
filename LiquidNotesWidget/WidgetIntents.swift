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
        // Use URL scheme to trigger action in main app
        guard let url = URL(string: "liquidnotes://action/toggle-favorite/\(noteID)") else {
            return .result()
        }
        
        return .result(opensIntent: OpenURLIntent(url))
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
        guard let url = URL(string: "liquidnotes://note/\(noteID)") else {
            return .result()
        }
        
        return .result(opensIntent: OpenURLIntent(url))
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
        // Use URL scheme to trigger action in main app
        guard let url = URL(string: "liquidnotes://action/add-task/\(noteID)") else {
            return .result()
        }
        
        return .result(opensIntent: OpenURLIntent(url))
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
        // Use URL scheme to trigger action in main app
        guard let url = URL(string: "liquidnotes://action/complete-task/\(noteID)/\(taskIndex)") else {
            return .result()
        }
        
        return .result(opensIntent: OpenURLIntent(url))
    }
}