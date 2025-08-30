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
    @State private var showingTaskList = false
    @State private var showingTagEditor = false
    @State private var tempTags: [String] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                VStack(spacing: 16) {
                    TextField("Note Title", text: $title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .onChange(of: title) { oldValue, newValue in
                            hasChanges = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(.clear)
                        .modernGlassCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                
                RichTextEditor(
                    text: $content,
                    attributedText: $attributedContent,
                    placeholder: "Start typing your note...",
                    onTextChanged: {
                        hasChanges = true
                    }
                )
                .onChange(of: attributedContent) { oldValue, newValue in
                    hasChanges = true
                }
                .onChange(of: content) { oldValue, newValue in
                    hasChanges = true
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.clear)
                .modernGlassCard()
                .padding(.horizontal, 20)
                
                if showingTaskList {
                    TaskListView(
                        tasks: .constant([]), // note.tasks), // Temporarily disabled
                        onToggle: { index in
                            note.toggleTask(at: index)
                            hasChanges = true
                        },
                        onDelete: { index in
                            note.removeTask(at: index)
                            hasChanges = true
                        },
                        onAdd: { text in
                            note.addTask(text)
                            hasChanges = true
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                if showingTagEditor {
                    TagListView(
                        tags: $tempTags,
                        onAdd: { tag in
                            note.addTag(tag)
                            tempTags = note.tags
                            hasChanges = true
                        },
                        onRemove: { tag in
                            note.removeTag(tag)
                            tempTags = note.tags
                            hasChanges = true
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                if !note.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Attachments")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(note.attachments.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.tertiary.opacity(0.2), in: Capsule())
                        }
                        .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(zip(note.attachments.indices, note.attachments)), id: \.0) { index, data in
                                    if index < note.attachmentTypes.count {
                                        AttachmentView(
                                            data: data,
                                            type: note.attachmentTypes[index],
                                            onDelete: {
                                                if index < note.attachments.count && index < note.attachmentTypes.count {
                                                    withAnimation(.bouncy(duration: 0.4)) {
                                                        note.removeAttachment(at: index)
                                                        hasChanges = true
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                    }
                    .background(.clear)
                    .ambientGlassEffect()
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                }
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
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.bouncy(duration: 0.3)) {
                                showingTaskList.toggle()
                            }
                        }) {
                            Image(systemName: showingTaskList ? "checklist.checked" : "checklist")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: showingTaskList ? [.green, .mint] : [Color.gray, Color.gray.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            withAnimation(.bouncy(duration: 0.3)) {
                                showingTagEditor.toggle()
                            }
                        }) {
                            Image(systemName: showingTagEditor ? "tag.fill" : "tag")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: showingTagEditor ? [.purple, .pink] : [Color.gray, Color.gray.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            showingGiphyPicker = true
                        }) {
                            Image(systemName: "face.smiling")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .buttonStyle(.borderless)
                        
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .any(of: [.images, .livePhotos]),
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Save") {
                            saveNote()
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .disabled(!hasChanges && !isNewNote)
                        .foregroundStyle((hasChanges || isNewNote) ? Color.accentColor : Color.secondary)
                        .scaleEffect((hasChanges || isNewNote) ? 1.05 : 1.0)
                        .animation(.bouncy(duration: 0.3), value: hasChanges)
                    }
                }
            }
            .onAppear {
                loadNoteData()
                // Initialize tempTags from note
                tempTags = note.tags
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
        // Sync tags back if user edited locally (should already be in note via add/remove, but ensure)
        if note.tags != tempTags {
            note.tags = tempTags
        }
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
        // Revert tempTags if cancel
        tempTags = note.tags
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