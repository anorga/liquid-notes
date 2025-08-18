//
//  NoteCardView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI

struct NoteCardView: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void
    
    var body: some View {
        // Using standard SwiftUI components for automatic Liquid Glass
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            HStack {
                Text(note.modifiedDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding()
        .liquidGlassCard() // Use system materials
        .frame(width: 200, height: 150)
        .onTapGesture {
            HapticManager.shared.noteSelected()
            onTap()
        }
        .contextMenu {
            Button(action: {
                HapticManager.shared.buttonTapped()
                onPin()
            }) {
                Label(note.isPinned ? "Unpin" : "Pin", 
                      systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    let sampleNote = Note(
        title: "Sample Note",
        content: "This is a sample note with some content to show how it looks in the card view."
    )
    sampleNote.tags = ["work", "important"]
    sampleNote.isPinned = true
    
    return NoteCardView(
        note: sampleNote,
        onTap: {},
        onDelete: {},
        onPin: {}
    )
    .padding()
    .background(.gray.opacity(0.1))
}