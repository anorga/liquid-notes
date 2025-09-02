import SwiftUI
import PhotosUI

struct ModernFormattingToolbar: View {
    let onFormatAction: (TextFormat) -> Void
    let onPhotoSelect: (PhotosPickerItem) -> Void
    let onGifSelect: () -> Void
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                // Text Styles Group
                Group {
                    formatButton(title: "Title", icon: "textformat.size.larger", color: .primary) {
                        onFormatAction(.title)
                    }
                    
                    formatButton(title: "Heading", icon: "textformat", color: .primary) {
                        onFormatAction(.heading)
                    }
                    
                    formatButton(title: "Body", icon: "textformat.abc", color: .primary) {
                        onFormatAction(.body)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                    .foregroundStyle(.quaternary)
                
                // Character Formatting Group
                Group {
                    formatButton(title: "Bold", icon: "bold", color: .blue) {
                        onFormatAction(.bold)
                    }
                    
                    formatButton(title: "Italic", icon: "italic", color: .blue) {
                        onFormatAction(.italic)
                    }
                    
                    formatButton(title: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .purple) {
                        onFormatAction(.monospace)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                    .foregroundStyle(.quaternary)
                
                // Lists and Structure Group
                Group {
                    formatButton(title: "Bullet", icon: "list.bullet", color: .green) {
                        onFormatAction(.bulletList)
                    }
                    
                    formatButton(title: "Number", icon: "list.number", color: .green) {
                        onFormatAction(.numberedList)
                    }
                    
                    formatButton(title: "Task", icon: "checklist", color: .orange) {
                        onFormatAction(.checkbox)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                    .foregroundStyle(.quaternary)
                
                // Media Group
                Group {
                    PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .livePhotos])) {
                        formatButton(title: "Photo", icon: "photo", color: .cyan) { }
                    }
                    
                    formatButton(title: "GIF", icon: "face.smiling", color: .yellow) {
                        onGifSelect()
                    }
                    
                    formatButton(title: "Link", icon: "link", color: .blue) {
                        // Insert link brackets - the editor will handle autocomplete
                        insertLinkBrackets()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .onChange(of: selectedPhoto) { _, newPhoto in
            if let photo = newPhoto {
                onPhotoSelect(photo)
                selectedPhoto = nil
            }
        }
    }
    
    @ViewBuilder
    private func formatButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(color.opacity(0.2), lineWidth: 1)
                            )
                    )
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 50)
    }
    
    private func insertLinkBrackets() {
        // This would need access to the text view to insert [[ at cursor
        // For now, we'll rely on the user typing [[
    }
}

#Preview {
    ModernFormattingToolbar(
        onFormatAction: { _ in },
        onPhotoSelect: { _ in },
        onGifSelect: { }
    )
    .background(.regularMaterial)
}