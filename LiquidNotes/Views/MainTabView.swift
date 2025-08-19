//
//  MainTabView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/18/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            // Home Tab
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            
            // Pins Tab  
            Tab("Pins", systemImage: "pin.fill") {
                PinnedNotesView()
            }
            
            // Search Tab (trailing)
            Tab(role: .search) {
                SearchView()
            }
        }
        // Let tab bar use native Liquid Glass automatically
    }
}

#Preview {
    MainTabView()
        .modelContainer(DataContainer.previewContainer)
}