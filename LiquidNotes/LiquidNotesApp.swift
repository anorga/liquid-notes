//
//  LiquidNotesApp.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData

@main
struct LiquidNotesApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear { NotificationScheduler.requestAuthIfNeeded() }
        }
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self, TaskItem.self])
    }
}
// CommandTrigger & command menus removed (simplification)
