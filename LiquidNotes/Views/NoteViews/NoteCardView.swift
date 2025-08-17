//
//  NoteCardView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI

struct NoteCardView: View {
    let note: Note
    let theme: GlassTheme
    let motionData: MotionManager.MotionData
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isPressed = false
    
    var body: some View {
        LiquidGlassView(theme: theme, motionData: motionData) {
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
                        .foregroundColor(.tertiary)
                    
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
                                    .foregroundColor(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 200, height: 150)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .onTapGesture {
            HapticManager.shared.noteSelected()
            onTap()
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    if !isPressed {
                        isPressed = true
                        HapticManager.shared.noteMoved()
                    }
                }
                .onEnded { value in
                    isPressed = false
                    
                    // Check if dragged far enough to delete
                    if abs(value.translation.x) > 100 || abs(value.translation.y) > 100 {
                        HapticManager.shared.noteDeleted()
                        onDelete()
                    } else {
                        HapticManager.shared.noteDropped()
                        dragOffset = .zero
                    }
                }
        )
        .contextMenu {
            Button(action: onTap) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: {
                // Toggle pin functionality would go here
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
        content: "This is a sample note with some content to show how it looks in the card view.",
        glassThemeID: "clear"
    )
    sampleNote.tags = ["work", "important"]
    sampleNote.isPinned = true
    
    return NoteCardView(
        note: sampleNote,
        theme: GlassTheme.defaultThemes[0],
        motionData: MotionManager.MotionData(),
        onTap: {},
        onDelete: {}
    )
    .padding()
    .background(.gray.opacity(0.1))
}