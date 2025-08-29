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
                    .onChange(of: title) { oldValue, newValue in
                        hasChanges = true
                    }
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                
                // Rich Content Field with native keyboard font support
                RichTextEditor(
                    text: $content,
                    attributedText: $attributedContent,
                    placeholder: "Start typing your note...",
                    onTextChanged: {
                        // iOS 26: Direct callback ensures hasChanges is always triggered
                        hasChanges = true
                    }
                )
                .onChange(of: attributedContent) { oldValue, newValue in
                    hasChanges = true
                }
                .onChange(of: content) { oldValue, newValue in
                    // iOS 26: Additional change detection for plain text changes
                    hasChanges = true
                }
                
                // Attachments Section - Enhanced for iOS 26 with better spacing
                if !note.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(zip(note.attachments.indices, note.attachments)), id: \.0) { index, data in
                                if index < note.attachmentTypes.count {
                                    AttachmentView(
                                        data: data,
                                        type: note.attachmentTypes[index],
                                        onDelete: {
                                            // iOS 26: Safe attachment removal with bounds checking
                                            if index < note.attachments.count && index < note.attachmentTypes.count {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    note.removeAttachment(at: index)
                                                    hasChanges = true
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                    }
                    .padding(.vertical, 10)
                    .frame(minHeight: 200) 
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingGiphyPicker = true
                        }) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(.blue)
                        }
                        
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
                        .foregroundStyle((hasChanges || isNewNote) ? Color.accentColor : Color.secondary)
                        .animation(.easeInOut(duration: 0.2), value: hasChanges)
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
        let wasEmpty = note.title.isEmpty && note.content.isEmpty
        
        title = note.title
        content = note.content
        attributedContent = NSAttributedString(string: note.content)
        isNewNote = wasEmpty
        
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.isNewNote {
                self.hasChanges = false
            } else {
                self.hasChanges = true
            }
        }
    }
    
    private func saveNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        note.title = trimmedTitle
        note.content = trimmedContent
        note.updateModifiedDate()
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
            
            hasChanges = false
        } catch {
            print("❌ Failed to save note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func cancelEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
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

struct AttachmentView: View {
    let data: Data
    let type: String
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var sizeScale: CGFloat = 1.0
    @State private var showingResizeOptions = false
    
    private var adaptiveSize: CGSize {
        if let uiImage = UIImage(data: data) {
            let originalSize = uiImage.size
            let baseMaxWidth: CGFloat = 280
            let baseMaxHeight: CGFloat = 200
            
            let maxWidth = baseMaxWidth * sizeScale
            let maxHeight = baseMaxHeight * sizeScale
            
            let ratio = min(maxWidth / originalSize.width, maxHeight / originalSize.height)
            return CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }
        return CGSize(width: 280 * sizeScale, height: 200 * sizeScale)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if type.hasPrefix("image/") {
                if type == "image/gif" {
                    AnimatedImageView(data: data)
                        .frame(width: adaptiveSize.width, height: adaptiveSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .allowsHitTesting(false) // Ensure this doesn't block touches
                } else if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(uiImage.size.width / uiImage.size.height, contentMode: .fit)
                        .frame(width: adaptiveSize.width, height: adaptiveSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .allowsHitTesting(false) // Ensure this doesn't block touches
                }
            }
            
            // Delete button with better positioning
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .background(Color.white, in: Circle())
                    .font(.system(size: 18, weight: .medium))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .offset(x: 6, y: -6) // Reduced offset to stay within bounds
            .zIndex(10) // Ensure delete button is always on top
        }
        .frame(width: adaptiveSize.width + 12, height: adaptiveSize.height + 12) // Account for delete button
        .contextMenu {
            // Resize options
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    sizeScale = 0.7
                }
                HapticManager.shared.buttonTapped()
            }) {
                Label("Small", systemImage: "photo")
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    sizeScale = 1.0
                }
                HapticManager.shared.buttonTapped()
            }) {
                Label("Medium", systemImage: "photo")
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    sizeScale = 1.3
                }
                HapticManager.shared.buttonTapped()
            }) {
                Label("Large", systemImage: "photo")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
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

// iOS 26 Enhanced Animated GIF view using UIImageView
struct AnimatedImageView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.isUserInteractionEnabled = false // Critical: prevent blocking touches
        imageView.backgroundColor = UIColor.clear
        
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