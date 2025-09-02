import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct ModernNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    
    @State private var attributedText = AttributedString()
    @State private var hasChanges = false
    @State private var isNewNote = false
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingGiphyPicker = false
    @State private var showingShareSheet = false
    @State private var showingFormattingBar = false
    @State private var textEditor: ModernTextEditor?
    
    @State private var linkQuery: String = ""
    @State private var showLinkOverlay = false
    @State private var linkAnchorRect: CGRect = .zero
    @State private var activeTextView: UITextView? = nil
    
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern glass background
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Navigation Bar
                    modernNavBar
                        .background(.regularMaterial)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundStyle(.quaternary)
                        }
                    
                    // Main Text Editor
                    textEditorContainer
                        .overlay(alignment: .topLeading) { linkOverlay }
                    
                    // Formatting Toolbar
                    if showingFormattingBar {
                        modernFormattingBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(1)
                    }
                    
                    // Bottom Toolbar
                    modernBottomBar
                        .background(.regularMaterial)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundStyle(.quaternary)
                        }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { loadNoteData() }
        .onDisappear { saveNoteIfNeeded() }
        .onChange(of: selectedPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            loadPhotoData(from: newPhoto)
        }
        .sheet(isPresented: $showingGiphyPicker) { giphySheet }
        .sheet(isPresented: $showingShareSheet) { shareSheet }
    }
    
    // MARK: - Navigation Bar
    
    private var modernNavBar: some View {
        HStack(spacing: 16) {
            Button(action: { cancelEdit() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.quaternary.opacity(0.5), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if hasChanges || isNewNote {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(.blue.opacity(0.1), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: { saveNote(); dismiss() }) {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            if hasChanges || isNewNote {
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                            } else {
                                Circle()
                                    .fill(.quaternary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges && !isNewNote)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Text Editor Container
    
    private var textEditorContainer: some View {
        TextEditorView(
            attributedText: $attributedText,
            hasChanges: $hasChanges,
            textEditor: $textEditor,
            showingFormattingBar: $showingFormattingBar,
            linkQuery: $linkQuery,
            linkAnchorRect: $linkAnchorRect,
            showLinkOverlay: $showLinkOverlay,
            activeTextView: $activeTextView,
            onTextChanged: { updateNoteFromText() }
        )
    }
    
    // MARK: - Formatting Toolbar
    
    private var modernFormattingBar: some View {
        ModernFormattingToolbar(
            onFormatAction: { format in
                applyFormatting(format)
            },
            onPhotoSelect: { selectedPhoto = $0 },
            onGifSelect: { showingGiphyPicker = true }
        )
        .padding(.vertical, 12)
    }
    
    // MARK: - Bottom Toolbar
    
    private var modernBottomBar: some View {
        HStack(spacing: 0) {
            // Format Toggle
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    showingFormattingBar.toggle()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "textformat")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.blue)
                    
                    Text("Format")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
            
            // Photo Picker
            PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .livePhotos])) {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.green)
                    
                    Text("Photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
            
            // GIF Button
            Button(action: { showingGiphyPicker = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.orange)
                    
                    Text("GIF")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
            
            // Task Button
            Button(action: { applyFormatting(.checkbox) }) {
                VStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.purple)
                    
                    Text("Task")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
            
            // Link Button
            Button(action: { insertTextAtCursor("[[") }) {
                VStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.cyan)
                    
                    Text("Link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Sheets and Overlays
    
    private var shareSheet: some View {
        ShareLink(item: createShareURL() ?? URL(string: "about:blank")!) {
            Label("Share Note", systemImage: "square.and.arrow.up")
        }
    }
    
    private var giphySheet: some View {
        GiphyPicker(isPresented: $showingGiphyPicker) { gifData in
            note.addAttachment(data: gifData, type: "image/gif")
            hasChanges = true
        }
    }
    
    // MARK: - Link Overlay (same as before)
    
    @ViewBuilder private var linkOverlay: some View {
        if showLinkOverlay {
            VStack(alignment: .leading, spacing: 0) {
                if filteredLinkCandidates.isEmpty {
                    linkCreationButton
                }
                
                ForEach(filteredLinkCandidates.prefix(6), id: \.id) { candidate in
                    linkCandidateButton(candidate)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, max(0, linkAnchorRect.minY + 10))
            .padding(.leading, max(0, linkAnchorRect.minX + 10))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLinkOverlay)
        }
    }
    
    private var linkCreationButton: some View {
        Button(action: { createAndInsertLink() }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                Text("Create '\(linkQuery.trimmingCharacters(in: .whitespaces))'")
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(.green.opacity(0.05))
    }
    
    private func linkCandidateButton(_ candidate: Note) -> some View {
        Button(action: { insertLink(candidate) }) {
            HStack(spacing: 10) {
                Image(systemName: candidate.isFavorited ? "star.fill" : "note.text")
                    .foregroundStyle(candidate.isFavorited ? .yellow : .secondary)
                    .frame(width: 20)
                
                Text(candidate.title.isEmpty ? "Untitled" : candidate.title)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.3))
    }
    
    // MARK: - Formatting Methods
    
    private func applyFormatting(_ format: TextFormat) {
        guard let textView = activeTextView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableAttributedText = NSMutableAttributedString(attributedText)
        
        switch format {
        case .title:
            applyTextStyle(to: mutableAttributedText, range: selectedRange, 
                          font: .systemFont(ofSize: 28, weight: .bold))
        case .heading:
            applyTextStyle(to: mutableAttributedText, range: selectedRange, 
                          font: .systemFont(ofSize: 22, weight: .semibold))
        case .body:
            applyTextStyle(to: mutableAttributedText, range: selectedRange, 
                          font: .systemFont(ofSize: 18, weight: .regular))
        case .bold:
            toggleBoldFormatting(in: mutableAttributedText, range: selectedRange)
        case .italic:
            toggleItalicFormatting(in: mutableAttributedText, range: selectedRange)
        case .monospace:
            applyTextStyle(to: mutableAttributedText, range: selectedRange, 
                          font: .monospacedSystemFont(ofSize: 16, weight: .regular))
        case .bulletList:
            insertTextAtCursor("• ")
        case .numberedList:
            insertTextAtCursor("1. ")
        case .checkbox:
            insertTextAtCursor("\u{2610} ")
        }
        
        // Update the text view and binding
        textView.attributedText = mutableAttributedText
        attributedText = AttributedString(mutableAttributedText)
        hasChanges = true
    }
    
    private func applyTextStyle(to attributedText: NSMutableAttributedString, range: NSRange, font: UIFont) {
        if range.length > 0 {
            attributedText.addAttribute(.font, value: font, range: range)
        }
    }
    
    private func toggleBoldFormatting(in attributedText: NSMutableAttributedString, range: NSRange) {
        guard range.length > 0 else { return }
        
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let currentFont = value as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    let traits = currentFont.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                } else {
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits([currentFont.fontDescriptor.symbolicTraits, .traitBold])
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                }
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func toggleItalicFormatting(in attributedText: NSMutableAttributedString, range: NSRange) {
        guard range.length > 0 else { return }
        
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let currentFont = value as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    let traits = currentFont.fontDescriptor.symbolicTraits.subtracting(.traitItalic)
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                } else {
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits([currentFont.fontDescriptor.symbolicTraits, .traitItalic])
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                }
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func insertTextAtCursor(_ text: String) {
        guard let textView = activeTextView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        let insertText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ]
        )
        
        mutableText.insert(insertText, at: selectedRange.location)
        textView.attributedText = mutableText
        attributedText = AttributedString(mutableText)
        
        // Move cursor after inserted text
        textView.selectedRange = NSRange(location: selectedRange.location + text.count, length: 0)
        hasChanges = true
    }
    
    // MARK: - Data Management
    
    private func loadNoteData() {
        isNewNote = note.title.isEmpty && note.content.isEmpty
        
        var fullText = ""
        if !note.title.isEmpty {
            fullText = note.title
        }
        if !note.content.isEmpty {
            if !fullText.isEmpty { fullText += "\n" }
            fullText += note.content
        }
        
        attributedText = AttributedString(fullText)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hasChanges = isNewNote
        }
    }
    
    private func updateNoteFromText() {
        let textString = String(attributedText.characters)
        let lines = textString.components(separatedBy: .newlines)
        
        let newTitle = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newContent = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if note.title != newTitle || note.content != newContent {
            note.title = newTitle
            note.content = newContent
            note.updateModifiedDate()
        }
    }
    
    private func saveNote() {
        updateNoteFromText()
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
            hasChanges = false
        } catch {
            print("Failed to save note: \(error)")
            HapticManager.shared.error()
        }
    }
    
    private func saveNoteIfNeeded() {
        if hasChanges {
            saveNote()
        }
    }
    
    private func cancelEdit() {
        updateNoteFromText()
        
        if isNewNote && note.title.isEmpty && note.content.isEmpty {
            modelContext.delete(note)
            try? modelContext.save()
        }
        dismiss()
    }
    
    private func createShareURL() -> URL? {
        let text = String(attributedText.characters)
        let components = text.components(separatedBy: "\n")
        let title = components.first ?? "Note"
        let content = components.dropFirst().joined(separator: "\n")
        
        var shareText = title
        if !content.isEmpty {
            shareText += "\n\n" + content
        }
        
        guard let data = shareText.data(using: .utf8) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).txt")
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func loadPhotoData(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    textEditor?.insertImage(image)
                    hasChanges = true
                    selectedPhoto = nil
                    HapticManager.shared.buttonTapped()
                }
            }
        }
    }
}


// MARK: - Link Management Extensions

private extension ModernNoteEditorView {
    var filteredLinkCandidates: [Note] {
        let query = linkQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allNotes
            .filter { $0.id != note.id }
            .filter { query.isEmpty || $0.title.lowercased().contains(query) }
            .sorted { first, second in
                let firstScore = linkScore(for: first, query: query)
                let secondScore = linkScore(for: second, query: query)
                return firstScore > secondScore
            }
            .prefix(6)
            .map { $0 }
    }
    
    private func linkScore(for note: Note, query: String) -> Double {
        var score: Double = 0
        let title = note.title.lowercased()
        
        if query.isEmpty {
            score = 1
        } else {
            if title.hasPrefix(query) { score += 10 }
            else if title.contains(query) { score += 5 }
        }
        
        score += Double(note.linkUsageCount) * 0.1
        
        if let lastLinked = note.lastLinkedDate {
            let hoursSince = Date().timeIntervalSince(lastLinked) / 3600
            score += max(0, 5 - hoursSince)
        }
        
        return score
    }
    
    func insertLink(_ target: Note) {
        // Implementation would need access to the active text view
        // For now, this is a placeholder
        showLinkOverlay = false
        target.linkUsageCount += 1
        target.lastLinkedDate = Date()
    }
    
    func createAndInsertLink() {
        let title = linkQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        NotificationCenter.default.post(name: .lnCreateAndLinkNoteRequested, object: title)
        showLinkOverlay = false
    }
}


#Preview {
    let sampleNote = Note(title: "Sample Note", content: "This is a sample note")
    
    ModernNoteEditorView(note: sampleNote)
        .modelContainer(for: [Note.self, NoteCategory.self], inMemory: true)
}