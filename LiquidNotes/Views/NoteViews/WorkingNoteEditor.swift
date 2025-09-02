import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct WorkingNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    
    @State private var textView: UITextView?
    @State private var hasChanges = false
    @State private var isNewNote = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingGiphyPicker = false
    @State private var showingShareSheet = false
    @State private var showingToolbar = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Glass background
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top navigation
                    topNavigation
                    
                    // Text editor
                    WorkingTextEditor(
                        note: note,
                        textView: $textView,
                        hasChanges: $hasChanges,
                        onKeyboardShow: { showingToolbar = true },
                        onKeyboardHide: { showingToolbar = false }
                    )
                    
                    // Formatting toolbar
                    if showingToolbar {
                        WorkingToolbar(
                            textView: textView,
                            onPhotoTap: { selectedPhoto = $0 },
                            onGifTap: { showingGiphyPicker = true }
                        )
                        .transition(.move(edge: .bottom))
                    }
                    
                    // Bottom toolbar
                    bottomToolbar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { setupNote() }
        .onDisappear { saveIfNeeded() }
        .onChange(of: selectedPhoto) { _, photo in
            if let photo = photo {
                insertPhoto(photo)
            }
        }
        .sheet(isPresented: $showingGiphyPicker) {
            GiphyPicker(isPresented: $showingGiphyPicker) { gifData in
                insertGifData(gifData)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            shareSheet
        }
    }
    
    private var topNavigation: some View {
        HStack {
            Button("Cancel") {
                cancelEdit()
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            if hasChanges || isNewNote {
                Text("Unsaved")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            Button("Share") {
                showingShareSheet = true
            }
            .foregroundStyle(.blue)
            
            Button("Save") {
                saveNote()
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(hasChanges || isNewNote ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(hasChanges || isNewNote ? .blue : .secondary.opacity(0.2), in: Capsule())
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var bottomToolbar: some View {
        HStack {
            Button("Format") {
                withAnimation { showingToolbar.toggle() }
            }
            .frame(maxWidth: .infinity)
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Photo")
            }
            .frame(maxWidth: .infinity)
            
            Button("GIF") {
                showingGiphyPicker = true
            }
            .frame(maxWidth: .infinity)
            
            Button("Task") {
                insertText("\u{2610} ")
            }
            .frame(maxWidth: .infinity)
            
            Button("Link") {
                insertText("[[]]")
                // Move cursor back 2 positions
                if let tv = textView {
                    let current = tv.selectedRange
                    tv.selectedRange = NSRange(location: current.location - 2, length: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var shareSheet: some View {
        let text = textView?.text ?? ""
        let lines = text.components(separatedBy: "\n")
        let title = lines.first ?? "Note"
        let content = lines.dropFirst().joined(separator: "\n")
        let shareText = title + (content.isEmpty ? "" : "\n\n" + content)
        
        return ShareLink(item: shareText) {
            Label("Share Note", systemImage: "square.and.arrow.up")
        }
    }
    
    // MARK: - Actions
    
    private func setupNote() {
        isNewNote = note.title.isEmpty && note.content.isEmpty
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hasChanges = isNewNote
        }
    }
    
    private func insertText(_ text: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        let insert = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ])
        mutableText.insert(insert, at: range.location)
        tv.attributedText = mutableText
        tv.selectedRange = NSRange(location: range.location + text.count, length: 0)
        hasChanges = true
    }
    
    private func insertPhoto(_ photo: PhotosPickerItem) {
        Task {
            if let data = try? await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    insertImage(image)
                }
            }
        }
    }
    
    private func insertGifData(_ data: Data) {
        if let image = UIImage(data: data) {
            insertImage(image)
        }
        note.addAttachment(data: data, type: "image/gif")
        hasChanges = true
    }
    
    private func insertImage(_ image: UIImage) {
        guard let tv = textView else { return }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        
        // Scale to fit
        let maxWidth: CGFloat = min(tv.frame.width - 40, 300)
        let scale = min(maxWidth / image.size.width, 200 / image.size.height)
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
        
        let imageString = NSAttributedString(attachment: attachment)
        let range = tv.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        
        // Insert with newlines
        let prefix = range.location == 0 ? "" : "\n"
        let suffix = "\n"
        let fullString = NSMutableAttributedString(string: prefix)
        fullString.append(imageString)
        fullString.append(NSAttributedString(string: suffix))
        
        mutableText.insert(fullString, at: range.location)
        tv.attributedText = mutableText
        tv.selectedRange = NSRange(location: range.location + fullString.length, length: 0)
        hasChanges = true
    }
    
    private func saveNote() {
        guard let tv = textView else { return }
        
        let text = tv.text ?? ""
        let lines = text.components(separatedBy: "\n")
        let title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        note.title = title
        note.content = content
        note.updateModifiedDate()
        
        do {
            try modelContext.save()
            hasChanges = false
            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
        }
    }
    
    private func saveIfNeeded() {
        if hasChanges {
            saveNote()
        }
    }
    
    private func cancelEdit() {
        if isNewNote && (textView?.text?.isEmpty ?? true) {
            modelContext.delete(note)
            try? modelContext.save()
        }
        dismiss()
    }
}

struct WorkingTextEditor: UIViewRepresentable {
    let note: Note
    @Binding var textView: UITextView?
    @Binding var hasChanges: Bool
    let onKeyboardShow: () -> Void
    let onKeyboardHide: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = .systemFont(ofSize: 18)
        tv.textColor = .label
        tv.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        tv.allowsEditingTextAttributes = true
        tv.isScrollEnabled = true
        tv.keyboardDismissMode = .interactive
        
        // Smart features
        tv.smartInsertDeleteType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        
        // Load initial content
        var fullText = ""
        if !note.title.isEmpty {
            fullText = note.title
        }
        if !note.content.isEmpty {
            if !fullText.isEmpty { fullText += "\n" }
            fullText += note.content
        }
        
        tv.text = fullText
        
        // Apply title formatting to first line
        DispatchQueue.main.async {
            context.coordinator.formatFirstLineAsTitle(tv)
        }
        
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        DispatchQueue.main.async {
            textView = uiView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: WorkingTextEditor
        
        init(_ parent: WorkingTextEditor) {
            self.parent = parent
            super.init()
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        @objc func keyboardWillShow() {
            parent.onKeyboardShow()
        }
        
        @objc func keyboardWillHide() {
            parent.onKeyboardHide()
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.hasChanges = true
            formatFirstLineAsTitle(textView)
        }
        
        func formatFirstLineAsTitle(_ textView: UITextView) {
            let text = textView.text ?? ""
            guard !text.isEmpty else { return }
            
            let lines = text.components(separatedBy: "\n")
            guard let firstLine = lines.first, !firstLine.isEmpty else { return }
            
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let firstLineRange = NSRange(location: 0, length: firstLine.count)
            
            // Apply title formatting to first line
            mutableText.addAttributes([
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.label
            ], range: firstLineRange)
            
            // Apply body formatting to rest
            if text.count > firstLine.count + 1 {
                let restRange = NSRange(location: firstLine.count + 1, length: text.count - firstLine.count - 1)
                mutableText.addAttributes([
                    .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                    .foregroundColor: UIColor.label
                ], range: restRange)
            }
            
            let selectedRange = textView.selectedRange
            textView.attributedText = mutableText
            textView.selectedRange = selectedRange
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

struct WorkingToolbar: View {
    let textView: UITextView?
    let onPhotoTap: (PhotosPickerItem) -> Void
    let onGifTap: () -> Void
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Text styles
                toolbarButton("Bold", icon: "bold") {
                    applyBold()
                }
                
                toolbarButton("Italic", icon: "italic") {
                    applyItalic()
                }
                
                toolbarButton("Title", icon: "textformat.size.larger") {
                    applyTitleFormat()
                }
                
                toolbarButton("Body", icon: "textformat.abc") {
                    applyBodyFormat()
                }
                
                Divider().frame(height: 20)
                
                // Lists
                toolbarButton("Bullet", icon: "list.bullet") {
                    insertText("• ")
                }
                
                toolbarButton("Number", icon: "list.number") {
                    insertText("1. ")
                }
                
                toolbarButton("Task", icon: "checklist") {
                    insertText("\u{2610} ")
                }
                
                Divider().frame(height: 20)
                
                // Media
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    toolbarButtonView("Photo", icon: "photo")
                }
                
                toolbarButton("GIF", icon: "face.smiling") {
                    onGifTap()
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(.regularMaterial)
        .onChange(of: selectedPhoto) { _, photo in
            if let photo = photo {
                onPhotoTap(photo)
                selectedPhoto = nil
            }
        }
    }
    
    @ViewBuilder
    private func toolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarButtonView(title, icon: icon)
        }
    }
    
    private func toolbarButtonView(_ title: String, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 44)
    }
    
    private func insertText(_ text: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        let insert = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ])
        mutableText.insert(insert, at: range.location)
        tv.attributedText = mutableText
        tv.selectedRange = NSRange(location: range.location + text.count, length: 0)
    }
    
    private func applyBold() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        mutableText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? UIFont {
                let newFont: UIFont
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    // Remove bold
                    let traits = font.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: font.pointSize)
                } else {
                    // Add bold
                    let descriptor = font.fontDescriptor.withSymbolicTraits([font.fontDescriptor.symbolicTraits, .traitBold])
                    newFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: font.pointSize)
                }
                mutableText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        tv.attributedText = mutableText
        tv.selectedRange = range
    }
    
    private func applyItalic() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        mutableText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? UIFont {
                let newFont: UIFont
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    // Remove italic
                    let traits = font.fontDescriptor.symbolicTraits.subtracting(.traitItalic)
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: font.pointSize)
                } else {
                    // Add italic
                    let descriptor = font.fontDescriptor.withSymbolicTraits([font.fontDescriptor.symbolicTraits, .traitItalic])
                    newFont = UIFont(descriptor: descriptor ?? font.fontDescriptor, size: font.pointSize)
                }
                mutableText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        tv.attributedText = mutableText
        tv.selectedRange = range
    }
    
    private func applyTitleFormat() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        mutableText.addAttributes([
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.label
        ], range: range)
        tv.attributedText = mutableText
        tv.selectedRange = range
    }
    
    private func applyBodyFormat() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: tv.attributedText)
        mutableText.addAttributes([
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.label
        ], range: range)
        tv.attributedText = mutableText
        tv.selectedRange = range
    }
}

#Preview {
    let note = Note(title: "Sample", content: "Content")
    WorkingNoteEditor(note: note)
        .modelContainer(for: [Note.self], inMemory: true)
}