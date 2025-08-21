//
//  NoteEditorView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var hasChanges = false
    @State private var isNewNote = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingGiphyPicker = false
    
    var body: some View {
        NavigationStack {
            // Using standard SwiftUI form components for automatic Liquid Glass
            VStack(spacing: 0) {
                // Title Field
                TextField("Note Title", text: $title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .onChange(of: title) { _, _ in
                        hasChanges = true
                    }
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                
                // Rich Content Field with native keyboard font support
                RichTextEditor(
                    text: $content,
                    attributedText: $attributedContent,
                    placeholder: "Start typing your note..."
                )
                .onChange(of: attributedContent) { _, _ in
                    hasChanges = true
                }
                
                // Attachments Section
                if !note.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<min(note.attachments.count, note.attachmentTypes.count), id: \.self) { index in
                                AttachmentView(
                                    data: note.attachments[index],
                                    type: note.attachmentTypes[index],
                                    onDelete: {
                                        note.removeAttachment(at: index)
                                        hasChanges = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 10)
                }
                
                Spacer()
            }
            // No background - let Liquid Glass handle transparency
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .foregroundStyle(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // GIF picker button
                        Button(action: {
                            showingGiphyPicker = true
                        }) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(.blue)
                        }
                        
                        // Photo/Sticker picker button
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .any(of: [.images, .livePhotos]),
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "photo.badge.plus")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Save") {
                            saveNote()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges && !isNewNote)
                        .foregroundStyle(.primary)
                        .opacity((hasChanges || isNewNote) ? 1.0 : 0.5)
                    }
                }
            }
            .onAppear {
                loadNoteData()
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                guard let newPhoto = newPhoto else { return }
                loadPhotoData(from: newPhoto)
            }
            .sheet(isPresented: $showingGiphyPicker) {
                GiphyPicker(isPresented: $showingGiphyPicker) { gifData in
                    note.addAttachment(data: gifData, type: "image/gif")
                    hasChanges = true
                }
            }
        }
    }
    
    private func loadNoteData() {
        // Store the initial state before setting values that might trigger onChange
        let wasEmpty = note.title.isEmpty && note.content.isEmpty
        
        title = note.title
        content = note.content
        isNewNote = wasEmpty
        
        // Set hasChanges AFTER setting the title/content to avoid onChange interference
        if !isNewNote {
            hasChanges = false
        } else {
            // For new notes, initially allow saving
            hasChanges = true
        }
    }
    
    private func saveNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Always save the note when user explicitly chooses to save
        note.title = trimmedTitle
        note.content = trimmedContent
        note.updateModifiedDate()
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
            
            // Reset hasChanges after successful save
            hasChanges = false
        } catch {
            print("❌ Failed to save note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func cancelEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only delete new notes that are completely empty (user never typed anything)
        if isNewNote && trimmedTitle.isEmpty && trimmedContent.isEmpty {
            modelContext.delete(note)
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete empty note: \(error)")
            }
        }
        dismiss()
    }
    
    private func loadPhotoData(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    note.addAttachment(data: data, type: mimeType)
                    hasChanges = true
                    selectedPhoto = nil
                    HapticManager.shared.buttonTapped()
                }
            }
        }
    }
    
}

#Preview {
    let sampleNote = Note(
        title: "Sample Note",
        content: "This is a sample note for preview"
    )
    
    NoteEditorView(note: sampleNote)
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}

// Attachment view for displaying images and GIFs
struct AttachmentView: View {
    let data: Data
    let type: String
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if type.hasPrefix("image/") {
                if type == "image/gif" {
                    // Animated GIF support
                    AnimatedImageView(data: data)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .clipped()
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .contentShape(Rectangle())
                } else if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(uiImage.size.width / uiImage.size.height, contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .clipped()
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .contentShape(Rectangle())
                }
            }
            
            // Delete button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .background(Color.white, in: Circle())
                    .font(.system(size: 16))
            }
            .offset(x: 8, y: -8)
        }
        .alert("Delete Attachment", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
                HapticManager.shared.buttonTapped()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this attachment?")
        }
    }
}

// Animated GIF view using UIImageView
struct AnimatedImageView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.isUserInteractionEnabled = false
        
        if let image = UIImage.animatedImageWithData(data) {
            imageView.image = image
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        if let image = UIImage.animatedImageWithData(data) {
            uiView.image = image
        }
    }
}

extension UIImage {
    static func animatedImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                // Get frame duration
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                    duration += frameDuration
                }
            }
        }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
}