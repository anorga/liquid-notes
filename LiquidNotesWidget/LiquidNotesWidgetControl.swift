//
//  LiquidNotesWidgetControl.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct QuickNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LiquidNotes.QuickNote") {
            ControlWidgetButton(action: CreateQuickNoteIntent()) {
                Image(systemName: "note.text.badge.plus")
                Text("New Note")
            }
        }
        .displayName("Quick Note")
        .description("Quickly create a new note")
    }
}

struct QuickTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LiquidNotes.QuickTask") {
            ControlWidgetButton(action: CreateQuickTaskIntent()) {
                Image(systemName: "checklist")
                Text("Quick Task")
            }
        }
        .displayName("Quick Task")
        .description("Quickly add a task to your notes")
    }
}

struct CreateQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Quick Note"
    static var description = IntentDescription("Create a new note in Liquid Notes")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct CreateQuickTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Quick Task"
    static var description = IntentDescription("Add a quick task to your notes")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

