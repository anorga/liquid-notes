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
    let onFavorite: () -> Void
    
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
                
                if note.isFavorited {
                    Image(systemName: "star.fill")
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
            
            // Show first attachment if available
            if !note.attachments.isEmpty, let firstAttachment = note.attachments.first,
               let firstType = note.attachmentTypes.first, firstType.hasPrefix("image/"),
               let uiImage = UIImage(data: firstAttachment) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 40)
                    .clipped()
                    .cornerRadius(6)
                    .opacity(0.9)
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
        .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)  // Apple-style subtle shadow
        .frame(width: 160, height: 120)
        .onTapGesture {
            HapticManager.shared.noteSelected()
            onTap()
        }
        .contextMenu {
            Button(action: {
                HapticManager.shared.buttonTapped()
                onFavorite()
            }) {
                Label(note.isFavorited ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: note.isFavorited ? "star.slash" : "star")
            }
            
            Button(action: {
                HapticManager.shared.buttonTapped()
                // Add share functionality if needed
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                HapticManager.shared.buttonTapped()
                onDelete()
            }) {
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
    sampleNote.isFavorited = true
    
    return NoteCardView(
        note: sampleNote,
        onTap: {},
        onDelete: {},
        onFavorite: {}
    )
    .padding()
    // No preview background - allow Liquid Glass transparency
}