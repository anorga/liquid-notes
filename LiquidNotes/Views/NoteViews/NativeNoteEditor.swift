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
    
    let note: Note
    
    @State private var textView: UITextView?
    @State private var hasChanges = false
    @State private var isNewNote = false
    @State private var showingShareSheet = false
    @State private var shareItem: String = ""
    
    var body: some View {
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
                        hasChanges: $hasChanges
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { setupEditor() }
        .onDisappear { saveIfNeeded() }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareItem])
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
}

struct NativeTextCanvas: UIViewRepresentable {
    let note: Note
    @Binding var textView: UITextView?
    @Binding var hasChanges: Bool
    
    func makeUIView(context: Context) -> NativeTextView {
        let textView = NativeTextView()
        textView.delegate = context.coordinator
        textView.note = note
        textView.hasChangesBinding = $hasChanges
        
        // Native iOS text view setup - no borders
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 17) // Native iOS font size
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.allowsEditingTextAttributes = true
        
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
                    .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                    .foregroundColor: UIColor.label
                ], range: titleRange)
            }
        }
        
        textView.attributedText = attributedText
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
               action == #selector(insertDivider) ||
               action == #selector(insertPhoto) ||
               action == #selector(insertFile)
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Add custom formatting menu
        let formatMenu = UIMenu(
            title: "Format",
            image: UIImage(systemName: "textformat"),
            children: [
                UIAction(title: "Bold", image: UIImage(systemName: "bold")) { _ in
                    self.formatBold()
                },
                UIAction(title: "Italic", image: UIImage(systemName: "italic")) { _ in
                    self.formatItalic()
                },
                UIAction(title: "Underline", image: UIImage(systemName: "underline")) { _ in
                    self.formatUnderline()
                },
                UIAction(title: "Strikethrough", image: UIImage(systemName: "strikethrough")) { _ in
                    self.formatStrikethrough()
                },
                UIAction(title: "Monospace", image: UIImage(systemName: "textformat.abc.dottedunderline")) { _ in
                    self.formatMonospace()
                },
                UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { _ in
                    self.formatHighlight()
                }
            ]
        )
        
        // Add text styles menu
        let stylesMenu = UIMenu(
            title: "Text Style",
            image: UIImage(systemName: "textformat.size"),
            children: [
                UIAction(title: "Title", image: UIImage(systemName: "textformat.size.larger")) { _ in
                    self.applyTextStyle(.title)
                },
                UIAction(title: "Heading", image: UIImage(systemName: "textformat")) { _ in
                    self.applyTextStyle(.heading)
                },
                UIAction(title: "Subheading", image: UIImage(systemName: "textformat.subscript")) { _ in
                    self.applyTextStyle(.subheading)
                },
                UIAction(title: "Body", image: UIImage(systemName: "textformat.abc")) { _ in
                    self.applyTextStyle(.body)
                }
            ]
        )
        
        // Add lists menu
        let listsMenu = UIMenu(
            title: "Lists",
            image: UIImage(systemName: "list.bullet"),
            children: [
                UIAction(title: "Bullet List", image: UIImage(systemName: "list.bullet")) { _ in
                    self.insertBulletList()
                },
                UIAction(title: "Numbered List", image: UIImage(systemName: "list.number")) { _ in
                    self.insertNumberedList()
                },
                UIAction(title: "Task List", image: UIImage(systemName: "checklist")) { _ in
                    self.insertTaskList()
                },
                UIAction(title: "Dashed List", image: UIImage(systemName: "list.dash")) { _ in
                    self.insertDashedList()
                }
            ]
        )
        
        // Add structure menu
        let structureMenu = UIMenu(
            title: "Structure",
            image: UIImage(systemName: "quote.bubble"),
            children: [
                UIAction(title: "Block Quote", image: UIImage(systemName: "quote.bubble")) { _ in
                    self.insertBlockQuote()
                },
                UIAction(title: "Divider", image: UIImage(systemName: "minus.forwardslash.plus")) { _ in
                    self.insertDivider()
                }
            ]
        )
        
        // Add media menu
        let mediaMenu = UIMenu(
            title: "Insert",
            image: UIImage(systemName: "plus"),
            children: [
                UIAction(title: "Photo", image: UIImage(systemName: "photo")) { _ in
                    self.insertPhoto()
                },
                UIAction(title: "File", image: UIImage(systemName: "doc")) { _ in
                    self.insertFile()
                },
                UIAction(title: "Link", image: UIImage(systemName: "link")) { _ in
                    self.insertLink()
                }
            ]
        )
        
        builder.insertChild(formatMenu, atStartOfMenu: .standardEdit)
        builder.insertChild(stylesMenu, atStartOfMenu: .standardEdit)
        builder.insertChild(listsMenu, atStartOfMenu: .standardEdit)
        builder.insertChild(structureMenu, atStartOfMenu: .standardEdit)
        builder.insertChild(mediaMenu, atStartOfMenu: .standardEdit)
    }
    
    // MARK: - Formatting Actions
    
    @objc func formatBold() {
        toggleAttribute(.font, transform: { font in
            guard let font = font as? UIFont else { return UIFont.systemFont(ofSize: 17, weight: .bold) }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold) ? 
                font.withoutTrait(.traitBold) : font.withTrait(.traitBold)
        })
    }
    
    @objc func formatItalic() {
        toggleAttribute(.font, transform: { font in
            guard let font = font as? UIFont else { return UIFont.italicSystemFont(ofSize: 17) }
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
        applyAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular))
    }
    
    @objc func formatHighlight() {
        // Show color picker for highlighting
        showColorPicker { color in
            self.applyAttribute(.backgroundColor, value: color)
        }
    }
    
    // MARK: - Text Styles
    
    enum TextStyle {
        case title, heading, subheading, body
        
        var font: UIFont {
            switch self {
            case .title: return .systemFont(ofSize: 28, weight: .bold)
            case .heading: return .systemFont(ofSize: 22, weight: .semibold)
            case .subheading: return .systemFont(ofSize: 20, weight: .medium)
            case .body: return .systemFont(ofSize: 17, weight: .regular)
            }
        }
    }
    
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
        insertListItem("\u{2610} ")
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
    
    @objc func insertPhoto() {
        presentPhotoPicker()
    }
    
    @objc func insertFile() {
        presentDocumentPicker()
    }
    
    @objc func insertLink() {
        insertText("[[]]")
        // Move cursor back 2 positions
        let newRange = NSRange(location: selectedRange.location - 2, length: 0)
        selectedRange = newRange
        
        // Enable link detection and formatting
        DispatchQueue.main.async {
            self.formatLinks()
        }
    }
    
    // MARK: - Link Handling
    
    func formatLinks() {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        regex.enumerateMatches(in: mutableText.string, range: NSRange(location: 0, length: mutableText.length)) { match, _, _ in
            guard let range = match?.range,
                  let linkRange = match?.range(at: 1) else { return }
            
            // Style the link
            mutableText.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: mutableText.string.substring(with: linkRange) ?? ""
            ], range: range)
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
        // For now, we'll show a basic preview
        let alertController = UIAlertController(
            title: "Link: \(cleanedTitle)",
            message: "This would show a preview of the linked note content.",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Open Note", style: .default) { _ in
            // Implement note navigation
            NotificationCenter.default.post(name: .lnOpenNoteRequested, object: linkText)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let viewController = findViewController() {
            // Position popover for iPad
            if let popover = alertController.popoverPresentationController {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                popover.sourceView = self
                popover.sourceRect = rect
            }
            
            viewController.present(alertController, animated: true)
        }
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
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.label
        ], range: titleRange)
        
        let currentRange = selectedRange
        attributedText = mutableText
        selectedRange = currentRange
        
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
            .font: UIFont.systemFont(ofSize: 17),
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
        let insertion = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 17),
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
        // Present native color picker
        if let viewController = self.findViewController() {
            let colorPicker = UIColorPickerViewController()
            let delegate = ColorPickerDelegate(completion: completion)
            colorPicker.delegate = delegate
            
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(colorPicker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            viewController.present(colorPicker, animated: true)
        }
    }
    
    private func presentPhotoPicker() {
        guard let viewController = findViewController() else { return }
        
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        let delegate = PhotoPickerDelegate { [weak self] results in
            self?.handlePhotoPickerResults(results)
        }
        picker.delegate = delegate
        
        // Store delegate to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        viewController.present(picker, animated: true)
    }
    
    private func presentDocumentPicker() {
        guard let viewController = findViewController() else { return }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        let delegate = DocumentPickerDelegate { [weak self] urls in
            self?.handleDocumentPickerResults(urls)
        }
        picker.delegate = delegate
        
        // Store delegate to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        viewController.present(picker, animated: true)
    }
    
    private func handlePhotoPickerResults(_ results: [PHPickerResult]) {
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let image = object as? UIImage {
                // Also get the data
                result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    DispatchQueue.main.async {
                        if let data = data {
                            self?.insertInlineImage(image, data: data)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDocumentPickerResults(_ urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Ensure we have access to the file
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        insertInlineFile(url)
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

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

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

class PhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    let completion: ([PHPickerResult]) -> Void
    
    init(completion: @escaping ([PHPickerResult]) -> Void) {
        self.completion = completion
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        completion(results)
    }
}

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {}
}

#Preview {
    let note = Note(title: "Sample", content: "Content")
    NativeNoteEditor(note: note)
        .modelContainer(for: [Note.self], inMemory: true)
}