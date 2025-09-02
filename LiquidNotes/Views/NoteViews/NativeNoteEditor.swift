import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Photos
import ObjectiveC

struct NativeNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    let note: Note
    
    @State private var textView: UITextView?
    @State private var hasChanges = false
    @State private var isNewNote = false
    @State private var showingShareSheet = false
    @State private var shareItem: String = ""
    @State private var selectedTextStyle: TextStyle = .body
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var showingGifPicker = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Pure liquid glass background - no borders
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Minimal top navigation - native style
                        nativeTopBar
                        
                        // Native text editor canvas
                        NativeTextCanvas(
                            note: note,
                            textView: $textView,
                            hasChanges: $hasChanges,
                            selectedTextStyle: $selectedTextStyle
                        )
                        
                        // Bottom formatting toolbar
                        formattingToolbar
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { setupEditor() }
            .onDisappear { saveIfNeeded() }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareItem])
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView { results in
                    handlePhotoPickerResults(results)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { urls in
                    handleDocumentPickerResults(urls)
                }
            }
            .sheet(isPresented: $showingGifPicker) {
                GifPickerView { results in
                    handlePhotoPickerResults(results) // GIFs handled same as photos
                }
            }
        }
    }
    
    private var formattingToolbar: some View {
        HStack(spacing: 16) {
            // Text styles group
            Menu {
                Button(action: { applyTextStyle(.title) }) {
                    Label("Title", systemImage: "textformat.size.larger")
                }
                Button(action: { applyTextStyle(.heading) }) {
                    Label("Heading", systemImage: "textformat")
                }
                Button(action: { applyTextStyle(.subheading) }) {
                    Label("Subheading", systemImage: "textformat.subscript")
                }
                Button(action: { applyTextStyle(.body) }) {
                    Label("Body", systemImage: "textformat.abc")
                }
            } label: {
                Image(systemName: "textformat.size")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Divider()
                .frame(height: 20)
            
            // Format group
            Menu {
                Button(action: { (textView as? NativeTextView)?.formatBold() }) {
                    Label("Bold", systemImage: "bold")
                }
                Button(action: { (textView as? NativeTextView)?.formatItalic() }) {
                    Label("Italic", systemImage: "italic")
                }
                Button(action: { (textView as? NativeTextView)?.formatUnderline() }) {
                    Label("Underline", systemImage: "underline")
                }
                Button(action: { (textView as? NativeTextView)?.formatStrikethrough() }) {
                    Label("Strikethrough", systemImage: "strikethrough")
                }
                Button(action: { (textView as? NativeTextView)?.formatMonospace() }) {
                    Label("Monospace", systemImage: "textformat.abc.dottedunderline")
                }
                Button(action: { (textView as? NativeTextView)?.formatHighlight() }) {
                    Label("Highlight", systemImage: "highlighter")
                }
            } label: {
                Image(systemName: "bold.italic.underline")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Divider()
                .frame(height: 20)
            
            // Lists group
            Menu {
                Button(action: { (textView as? NativeTextView)?.insertBulletList() }) {
                    Label("Bullet List", systemImage: "list.bullet")
                }
                Button(action: { (textView as? NativeTextView)?.insertNumberedList() }) {
                    Label("Numbered List", systemImage: "list.number")
                }
                Button(action: { (textView as? NativeTextView)?.insertTaskList() }) {
                    Label("Task List", systemImage: "checklist")
                }
                Button(action: { (textView as? NativeTextView)?.insertDashedList() }) {
                    Label("Dashed List", systemImage: "list.dash")
                }
                Button(action: { (textView as? NativeTextView)?.insertBlockQuote() }) {
                    Label("Block Quote", systemImage: "quote.bubble")
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Divider()
                .frame(height: 20)
            
            // Media group
            Button(action: { 
                showingPhotoPicker = true
            }) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Button(action: { 
                showingGifPicker = true
            }) {
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Button(action: { 
                showingDocumentPicker = true
            }) {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Button(action: { (textView as? NativeTextView)?.insertLink() }) {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
    }
    
    private var nativeTopBar: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                cancelEdit()
            }
            .foregroundStyle(.secondary)
            .font(.body)
            
            Spacer()
            
            Button(action: { shareNote() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            
            Button("Done") {
                saveNote()
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func setupEditor() {
        isNewNote = note.title.isEmpty && note.content.isEmpty
        hasChanges = isNewNote
    }
    
    private func shareNote() {
        guard let tv = textView else { return }
        shareItem = tv.text ?? ""
        showingShareSheet = true
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
    
    private func applyTextStyle(_ style: TextStyle) {
        if let nativeTextView = textView as? NativeTextView {
            nativeTextView.applyTextStyle(style)
        }
        selectedTextStyle = style
    }
    
    private func handlePhotoPickerResults(_ results: [PHPickerResult]) {
        guard let result = results.first,
              let nativeTextView = textView as? NativeTextView else { return }
        
        // Check if it's a GIF
        if result.itemProvider.hasItemConformingToTypeIdentifier("com.compuserve.gif") {
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: "com.compuserve.gif") { data, error in
                if let data = data {
                    DispatchQueue.main.async {
                        if let image = UIImage(data: data) {
                            nativeTextView.insertInlineImage(image, data: data)
                        }
                    }
                }
            }
        } else {
            // Handle regular images
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage {
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        DispatchQueue.main.async {
                            if let data = data {
                                nativeTextView.insertInlineImage(image, data: data)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleDocumentPickerResults(_ urls: [URL]) {
        guard let url = urls.first,
              let nativeTextView = textView as? NativeTextView else { return }
        
        // Ensure we have access to the file
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        nativeTextView.insertInlineFile(url)
    }
}

enum TextStyle {
    case title, heading, subheading, body
    
    var font: UIFont {
        switch self {
        case .title: return .systemFont(ofSize: 32, weight: .bold)
        case .heading: return .systemFont(ofSize: 26, weight: .semibold)
        case .subheading: return .systemFont(ofSize: 22, weight: .medium)
        case .body: return .systemFont(ofSize: 20, weight: .regular)
        }
    }
}

struct NativeTextCanvas: UIViewRepresentable {
    let note: Note
    @Binding var textView: UITextView?
    @Binding var hasChanges: Bool
    @Binding var selectedTextStyle: TextStyle
    
    func makeUIView(context: Context) -> NativeTextView {
        let textView = NativeTextView()
        textView.delegate = context.coordinator
        textView.note = note
        textView.hasChangesBinding = $hasChanges
        
        // Native iOS text view setup - no borders, larger text
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 20, weight: .regular) // Increased from 17
        textView.textColor = .label // Dynamic color for light/dark mode
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.allowsEditingTextAttributes = true
        
        // Set typing attributes for new text
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        
        // Enable native features
        textView.smartInsertDeleteType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.spellCheckingType = .yes
        textView.autocorrectionType = .yes
        
        // Load content
        loadNoteContent(into: textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: NativeTextView, context: Context) {
        DispatchQueue.main.async {
            textView = uiView
        }
    }
    
    private func loadNoteContent(into textView: UITextView) {
        var fullText = ""
        if !note.title.isEmpty {
            fullText = note.title
        }
        if !note.content.isEmpty {
            if !fullText.isEmpty { fullText += "\n" }
            fullText += note.content
        }
        
        let attributedText = NSMutableAttributedString(string: fullText)
        
        // Apply title formatting to first line
        if !fullText.isEmpty {
            let lines = fullText.components(separatedBy: "\n")
            if let firstLine = lines.first, !firstLine.isEmpty {
                let titleRange = NSRange(location: 0, length: firstLine.count)
                attributedText.addAttributes([
                    .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                    .foregroundColor: UIColor.label
                ], range: titleRange)
                
                // Apply body formatting to rest of content
                if fullText.count > firstLine.count + 1 {
                    let bodyRange = NSRange(location: firstLine.count + 1, length: fullText.count - firstLine.count - 1)
                    attributedText.addAttributes([
                        .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                        .foregroundColor: UIColor.label
                    ], range: bodyRange)
                }
            }
        } else {
            // If empty, set default attributes
            attributedText.addAttributes([
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.label
            ], range: NSRange(location: 0, length: fullText.count))
        }
        
        textView.attributedText = attributedText
        
        // Also format any existing links
        if let nativeTextView = textView as? NativeTextView {
            nativeTextView.formatLinks()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        func textViewDidChange(_ textView: UITextView) {
            if let nativeTextView = textView as? NativeTextView {
                nativeTextView.hasChangesBinding?.wrappedValue = true
                nativeTextView.formatFirstLineAsTitle()
            }
        }
    }
}

class NativeTextView: UITextView, UITextViewDelegate {
    var note: Note?
    var hasChangesBinding: Binding<Bool>?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTapGesture()
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Check if tap is on an attachment
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if characterIndex < attributedText.length {
            if let attachment = attributedText.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? InteractiveTextAttachment {
                // Convert location to attachment-relative coordinates
                let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
                let attachmentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let attachmentLocation = CGPoint(x: location.x - attachmentRect.minX, y: location.y - attachmentRect.minY)
                
                if attachment.handleTap(at: attachmentLocation, in: self) {
                    return // Tap was handled by attachment
                }
            }
            
            // Check if tap is on a link
            if let link = attributedText.attribute(.link, at: characterIndex, effectiveRange: nil) as? String {
                showLinkPreview(for: link, at: NSRange(location: characterIndex, length: 1))
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return super.canPerformAction(action, withSender: sender) || 
               action == #selector(formatBold) ||
               action == #selector(formatItalic) ||
               action == #selector(formatUnderline) ||
               action == #selector(formatStrikethrough) ||
               action == #selector(formatMonospace) ||
               action == #selector(formatHighlight) ||
               action == #selector(insertBulletList) ||
               action == #selector(insertNumberedList) ||
               action == #selector(insertTaskList) ||
               action == #selector(insertBlockQuote) ||
               action == #selector(insertDivider)
    }
    
    // MARK: - Formatting Actions
    
    @objc func formatBold() {
        toggleAttribute(.font, transform: { font in
            guard let font = font as? UIFont else { return UIFont.systemFont(ofSize: 20, weight: .bold) }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold) ? 
                font.withoutTrait(.traitBold) : font.withTrait(.traitBold)
        })
    }
    
    @objc func formatItalic() {
        toggleAttribute(.font, transform: { font in
            guard let font = font as? UIFont else { return UIFont.italicSystemFont(ofSize: 20) }
            return font.fontDescriptor.symbolicTraits.contains(.traitItalic) ? 
                font.withoutTrait(.traitItalic) : font.withTrait(.traitItalic)
        })
    }
    
    @objc func formatUnderline() {
        toggleAttribute(.underlineStyle) { existing in
            return (existing as? Int) == NSUnderlineStyle.single.rawValue ? 0 : NSUnderlineStyle.single.rawValue
        }
    }
    
    @objc func formatStrikethrough() {
        toggleAttribute(.strikethroughStyle) { existing in
            return (existing as? Int) == NSUnderlineStyle.single.rawValue ? 0 : NSUnderlineStyle.single.rawValue
        }
    }
    
    @objc func formatMonospace() {
        applyAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular))
    }
    
    @objc func formatHighlight() {
        // Show color picker for highlighting
        showColorPicker { color in
            self.applyAttribute(.backgroundColor, value: color.withAlphaComponent(0.3))
        }
    }
    
    // MARK: - Text Styles
    
    func applyTextStyle(_ style: TextStyle) {
        applyAttribute(.font, value: style.font)
    }
    
    // MARK: - Lists
    
    @objc func insertBulletList() {
        insertListItem("• ")
    }
    
    @objc func insertNumberedList() {
        insertListItem("1. ")
    }
    
    @objc func insertTaskList() {
        insertListItem("☐ ")
    }
    
    @objc func insertDashedList() {
        insertListItem("– ")
    }
    
    @objc func insertBlockQuote() {
        insertListItem("> ")
    }
    
    @objc func insertDivider() {
        insertText("\n---\n")
    }
    
    // MARK: - Media
    
    // Media insertion handled by SwiftUI toolbar, not context menu
    
    @objc func insertLink() {
        // Get selected text or prompt for link text
        let selectedText = getSelectedText()
        if !selectedText.isEmpty {
            // Wrap selected text in link format
            wrapSelectedTextAsLink(selectedText)
        } else {
            // Insert link template
            insertText("[[Link Text]]")
            // Move cursor inside brackets
            let newRange = NSRange(location: selectedRange.location - 2, length: 0)
            selectedRange = newRange
        }
    }
    
    private func getSelectedText() -> String {
        guard selectedRange.length > 0 else { return "" }
        let text = self.text ?? ""
        guard let range = Range(selectedRange, in: text) else { return "" }
        return String(text[range])
    }
    
    private func wrapSelectedTextAsLink(_ text: String) {
        guard selectedRange.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Create link with proper formatting
        let linkText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: text
        ])
        
        mutableText.replaceCharacters(in: selectedRange, with: linkText)
        
        let currentRange = NSRange(location: selectedRange.location + text.count, length: 0)
        attributedText = mutableText
        selectedRange = currentRange
        hasChangesBinding?.wrappedValue = true
    }
    
    // MARK: - Link Handling
    
    func formatLinks() {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        let matches = regex.matches(in: mutableText.string, range: NSRange(location: 0, length: mutableText.length))
        
        // Process matches in reverse to maintain indices
        for match in matches.reversed() {
            let linkRange = match.range(at: 1)
            guard linkRange.location != NSNotFound else { continue }
            
            let linkText = mutableText.string.substring(with: linkRange) ?? ""
            
            // Replace [[text]] with just the text, but styled as a link
            let styledLink = NSAttributedString(string: linkText, attributes: [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: linkText
            ])
            
            mutableText.replaceCharacters(in: match.range, with: styledLink)
        }
        
        let currentRange = selectedRange
        attributedText = mutableText
        selectedRange = currentRange
    }
    
    // Handle link taps for previews
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        // Show link preview
        showLinkPreview(for: URL.absoluteString, at: characterRange)
        return false
    }
    
    private func showLinkPreview(for linkText: String, at range: NSRange) {
        // Find the linked note
        let cleanedTitle = linkText.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
        
        // This would integrate with the existing note linking system
        let alertController = UIAlertController(
            title: cleanedTitle,
            message: "Navigate to this note?",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Open Note", style: .default) { _ in
            // Implement note navigation
            NotificationCenter.default.post(name: .lnOpenNoteRequested, object: cleanedTitle)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For now, just post the notification without showing preview
        // Link navigation will be handled by the app's existing system
        NotificationCenter.default.post(name: .lnOpenNoteRequested, object: cleanedTitle)
    }
    
    // MARK: - Attachment Handling
    
    func insertInlineImage(_ image: UIImage, data: Data) {
        let attachment = InteractiveTextAttachment()
        attachment.image = image
        attachment.note = self.note
        attachment.imageData = data
        
        // Scale to fit within text
        let maxWidth: CGFloat = min(frame.width - 40, 320)
        let scale = min(maxWidth / image.size.width, 240 / image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        attachment.bounds = CGRect(origin: .zero, size: scaledSize)
        
        let attachmentString = NSAttributedString(attachment: attachment)
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Insert with proper spacing
        let prefix = range.location == 0 ? "" : "\n"
        let suffix = "\n"
        let fullString = NSMutableAttributedString(string: prefix)
        fullString.append(attachmentString)
        fullString.append(NSAttributedString(string: suffix))
        
        mutableText.insert(fullString, at: range.location)
        attributedText = mutableText
        selectedRange = NSRange(location: range.location + fullString.length, length: 0)
        
        // Sync with note model
        note?.addAttachment(data: data, type: "image/jpeg")
        hasChangesBinding?.wrappedValue = true
    }
    
    func insertInlineFile(_ url: URL) {
        guard let fileData = try? Data(contentsOf: url) else { return }
        
        let attachment = InteractiveTextAttachment()
        attachment.note = self.note
        attachment.fileData = fileData
        attachment.fileName = url.lastPathComponent
        attachment.fileExtension = url.pathExtension
        
        // Create file icon representation
        let fileIcon = createFileIcon(for: url.pathExtension)
        attachment.image = fileIcon
        attachment.bounds = CGRect(x: 0, y: 0, width: 80, height: 40)
        
        let attachmentString = NSAttributedString(attachment: attachment)
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        let prefix = range.location == 0 ? "" : "\n"
        let suffix = " " + url.lastPathComponent + "\n"
        let fullString = NSMutableAttributedString(string: prefix)
        fullString.append(attachmentString)
        fullString.append(NSAttributedString(string: suffix))
        
        mutableText.insert(fullString, at: range.location)
        attributedText = mutableText
        selectedRange = NSRange(location: range.location + fullString.length, length: 0)
        
        // Sync with note model
        note?.addAttachment(data: fileData, type: "application/octet-stream")
        hasChangesBinding?.wrappedValue = true
    }
    
    private func createFileIcon(for fileExtension: String) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let iconName: String
        
        switch fileExtension.lowercased() {
        case "pdf": iconName = "doc.richtext"
        case "doc", "docx": iconName = "doc.text"
        case "xls", "xlsx": iconName = "tablecells"
        case "ppt", "pptx": iconName = "rectangle.on.rectangle"
        case "zip", "rar": iconName = "archivebox"
        case "mp4", "mov": iconName = "video"
        case "mp3", "wav": iconName = "music.note"
        case "gif": iconName = "photo.stack"
        default: iconName = "doc"
        }
        
        return UIImage(systemName: iconName, withConfiguration: config) ?? UIImage()
    }
    
    // MARK: - Helper Methods
    
    func formatFirstLineAsTitle() {
        guard let text = text, !text.isEmpty else { return }
        
        let lines = text.components(separatedBy: "\n")
        guard let firstLine = lines.first, !firstLine.isEmpty else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        let titleRange = NSRange(location: 0, length: firstLine.count)
        
        mutableText.addAttributes([
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.label
        ], range: titleRange)
        
        // Apply body font to rest of text
        if text.count > firstLine.count + 1 {
            let bodyRange = NSRange(location: firstLine.count + 1, length: text.count - firstLine.count - 1)
            mutableText.addAttributes([
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.label
            ], range: bodyRange)
        }
        
        let currentRange = selectedRange
        attributedText = mutableText
        selectedRange = currentRange
        
        // Update typing attributes based on cursor position
        if selectedRange.location == 0 || (selectedRange.location <= firstLine.count) {
            typingAttributes = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        } else {
            typingAttributes = [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.label
            ]
        }
        
        // Also format any links
        formatLinks()
    }
    
    private func toggleAttribute(_ key: NSAttributedString.Key, transform: (Any?) -> Any) {
        guard selectedRange.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        mutableText.enumerateAttribute(key, in: selectedRange) { value, range, _ in
            let newValue = transform(value)
            mutableText.addAttribute(key, value: newValue, range: range)
        }
        
        let currentRange = selectedRange
        attributedText = mutableText
        selectedRange = currentRange
        hasChangesBinding?.wrappedValue = true
    }
    
    private func applyAttribute(_ key: NSAttributedString.Key, value: Any) {
        guard selectedRange.length > 0 else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        mutableText.addAttribute(key, value: value, range: selectedRange)
        
        let currentRange = selectedRange
        attributedText = mutableText
        selectedRange = currentRange
        hasChangesBinding?.wrappedValue = true
    }
    
    private func insertListItem(_ prefix: String) {
        let range = selectedRange
        let line = getCurrentLine()
        let insertText = line.isEmpty ? prefix : "\n" + prefix
        
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        let insertion = NSAttributedString(string: insertText, attributes: [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.label
        ])
        
        mutableText.insert(insertion, at: range.location)
        attributedText = mutableText
        selectedRange = NSRange(location: range.location + insertText.count, length: 0)
        hasChangesBinding?.wrappedValue = true
    }
    
    override func insertText(_ text: String) {
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Maintain current font size or use default body size
        var currentFont = UIFont.systemFont(ofSize: 20, weight: .regular)
        if range.location > 0 && range.location <= mutableText.length {
            if let existingFont = mutableText.attribute(.font, at: max(0, range.location - 1), effectiveRange: nil) as? UIFont {
                currentFont = existingFont
            }
        }
        
        let insertion = NSAttributedString(string: text, attributes: [
            .font: currentFont,
            .foregroundColor: UIColor.label
        ])
        
        mutableText.insert(insertion, at: range.location)
        attributedText = mutableText
        selectedRange = NSRange(location: range.location + text.count, length: 0)
        hasChangesBinding?.wrappedValue = true
    }
    
    private func getCurrentLine() -> String {
        let text = self.text ?? ""
        let location = selectedRange.location
        
        guard location <= text.count else { return "" }
        
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
        
        return nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
    }
    
    private func showColorPicker(completion: @escaping (UIColor) -> Void) {
        // Use a simple color selection without UIKit presentation
        // For now, apply a default highlight color
        completion(UIColor.systemYellow.withAlphaComponent(0.3))
    }
    
    
    
    
}

// MARK: - Extensions

extension NativeTextView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension UIFont {
    func withTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits([fontDescriptor.symbolicTraits, trait])
        return UIFont(descriptor: descriptor ?? fontDescriptor, size: pointSize)
    }
    
    func withoutTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let traits = fontDescriptor.symbolicTraits.subtracting(trait)
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor ?? fontDescriptor, size: pointSize)
    }
}

// UIView extensions removed - using SwiftUI presentation

extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}

class ColorPickerDelegate: NSObject, UIColorPickerViewControllerDelegate {
    let completion: (UIColor) -> Void
    
    init(completion: @escaping (UIColor) -> Void) {
        self.completion = completion
    }
    
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        completion(viewController.selectedColor)
    }
}

// MARK: - Interactive Text Attachment

class InteractiveTextAttachment: NSTextAttachment {
    var note: Note?
    var imageData: Data?
    var fileData: Data?
    var fileName: String?
    var fileExtension: String?
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return bounds
    }
    
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        // Add delete button overlay for images
        if let baseImage = super.image(forBounds: imageBounds, textContainer: textContainer, characterIndex: charIndex) {
            return addDeleteButton(to: baseImage)
        }
        return image
    }
    
    private func addDeleteButton(to baseImage: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: baseImage.size)
        return renderer.image { context in
            // Draw base image
            baseImage.draw(at: .zero)
            
            // Draw delete button in top-right corner
            let buttonSize: CGFloat = 24
            let buttonFrame = CGRect(
                x: baseImage.size.width - buttonSize - 8,
                y: 8,
                width: buttonSize,
                height: buttonSize
            )
            
            // Semi-transparent background
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            context.cgContext.fillEllipse(in: buttonFrame)
            
            // X symbol
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(2)
            let inset: CGFloat = 6
            context.cgContext.move(to: CGPoint(x: buttonFrame.minX + inset, y: buttonFrame.minY + inset))
            context.cgContext.addLine(to: CGPoint(x: buttonFrame.maxX - inset, y: buttonFrame.maxY - inset))
            context.cgContext.move(to: CGPoint(x: buttonFrame.maxX - inset, y: buttonFrame.minY + inset))
            context.cgContext.addLine(to: CGPoint(x: buttonFrame.minX + inset, y: buttonFrame.maxY - inset))
            context.cgContext.strokePath()
        }
    }
    
    // Handle tap on attachment
    func handleTap(at point: CGPoint, in textView: UITextView) -> Bool {
        // Check if tap is on delete button
        let deleteButtonFrame = CGRect(
            x: bounds.width - 32,
            y: 8,
            width: 24,
            height: 24
        )
        
        if deleteButtonFrame.contains(point) {
            deleteAttachment(from: textView)
            return true
        }
        
        return false
    }
    
    private func deleteAttachment(from textView: UITextView) {
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        // Find this attachment in the attributed string
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            if let attachment = value as? InteractiveTextAttachment, attachment === self {
                // Remove from text
                mutableText.deleteCharacters(in: range)
                
                // Remove from note model
                if let note = self.note, let imageData = self.imageData {
                    if let index = note.attachments.firstIndex(of: imageData) {
                        note.removeAttachment(at: index)
                    }
                }
                
                stop.pointee = true
            }
        }
        
        textView.attributedText = mutableText
        
        // Update changes
        if let nativeTextView = textView as? NativeTextView {
            nativeTextView.hasChangesBinding?.wrappedValue = true
        }
    }
}

// MARK: - Delegates

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {}
}

struct PhotoPickerView: UIViewControllerRepresentable {
    let completion: ([PHPickerResult]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiView: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([PHPickerResult]) -> Void
        
        init(completion: @escaping ([PHPickerResult]) -> Void) {
            self.completion = completion
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            completion(results)
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiView: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void
        
        init(completion: @escaping ([URL]) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion([])
        }
    }
}

struct GifPickerView: UIViewControllerRepresentable {
    let completion: ([PHPickerResult]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images // This includes GIFs
        config.preferredAssetRepresentationMode = .current // Preserves GIF animation
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiView: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([PHPickerResult]) -> Void
        
        init(completion: @escaping ([PHPickerResult]) -> Void) {
            self.completion = completion
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            completion(results)
        }
    }
}

#Preview {
    let note = Note(title: "Sample", content: "Content")
    NativeNoteEditor(note: note)
        .modelContainer(for: [Note.self], inMemory: true)
}