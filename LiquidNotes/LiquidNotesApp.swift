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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasShownSplash") private var hasShownSplash = false
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear { NotificationScheduler.requestAuthIfNeeded() }
                .onAppear { configureWindowSizeRestrictions() }
                .onAppear { BadgeManager.shared.refreshBadgeCount() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    BadgeManager.shared.refreshBadgeCount()
                }
                .overlay(alignment: .center) {
                    if !hasShownSplash {
                        SplashView()
                            .transition(.opacity)
                            .onAppear {
                                // Dismiss after a brief moment; do not block app startup
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        hasShownSplash = true
                                    }
                                }
                            }
                    }
                }
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
