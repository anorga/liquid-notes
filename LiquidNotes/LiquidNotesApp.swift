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
    @State private var commandTrigger: CommandTrigger = CommandTrigger()
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(commandTrigger)
                .onAppear { NotificationScheduler.requestAuthIfNeeded() }
        }
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self, TaskItem.self])
        .commands {
            CommandMenu("Liquid Notes") {
                Button("Command Palette…") { commandTrigger.openPalette.toggle() }
                    .keyboardShortcut("k", modifiers: [.command])
                Divider()
                Button("New Quick Note") { commandTrigger.newQuickNote.toggle() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("New Full Note") { commandTrigger.newFullNote.toggle() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Daily Review") { commandTrigger.openDailyReview.toggle() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

@Observable final class CommandTrigger {
    var openPalette = false
    var newQuickNote = false
    var newFullNote = false
    var openDailyReview = false
}
