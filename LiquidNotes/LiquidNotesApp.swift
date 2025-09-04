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
                .onAppear { configureWindowSizeRestrictions() }
        }
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self, TaskItem.self])
    }
    
    private func configureWindowSizeRestrictions() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        // Configure minimum window size for iPad Stage Manager
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                // Set minimum width to prevent overly narrow windows
                // 500pt minimum width ensures editor remains usable
                // Maximum width unrestricted to allow full screen
                windowScene.sizeRestrictions?.minimumSize = CGSize(width: 500, height: 400)
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
            }
        }
        #endif
    }
}
// CommandTrigger & command menus removed (simplification)
