//
//  AddNoteButton.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI

// DEPRECATED: Replaced by FloatingActionButton; scheduled for removal after confirming no lingering references.
struct AddNoteButton: View {
    let action: () -> Void
    let onCreateFolder: (() -> Void)?
    
    @State private var showingActionSheet = false
    
    init(action: @escaping () -> Void, onCreateFolder: (() -> Void)? = nil) {
        self.action = action
        self.onCreateFolder = onCreateFolder
    }
    
    var body: some View {
        Button(action: {
            if onCreateFolder != nil {
                HapticManager.shared.buttonTapped()
                showingActionSheet = true
            } else {
                action()
            }
        }) {
            Image(systemName: "plus")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .symbolEffect(.bounce, value: showingActionSheet)
                .symbolRenderingMode(.monochrome)
                .background(Color.clear)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .confirmationDialog("Create New", isPresented: $showingActionSheet, titleVisibility: .hidden) {
            Button("Note", action: action)
            if let createFolder = onCreateFolder {
                Button("Folder", action: createFolder)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    AddNoteButton(action: {})
}