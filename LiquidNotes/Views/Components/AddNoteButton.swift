//
//  AddNoteButton.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI

struct AddNoteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .symbolEffect(.bounce, value: false)
                .symbolRenderingMode(.monochrome)
                .background(Color.clear)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
}

#Preview {
    AddNoteButton(action: {})
}