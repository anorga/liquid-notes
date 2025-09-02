import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Photos
import ObjectiveC
import ImageIO

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
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.6
    
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
                            selectedTextStyle: $selectedTextStyle,
                            modelContext: modelContext
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
                GiphyPicker(isPresented: $showingGifPicker) { gifData in
                    handleGiphySelection(gifData)
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
            
            Button(action: { showingGifPicker = true }) {
                Text("GIF")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 1))
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
        // Extract attributed string
        let attributed = tv.attributedText ?? NSAttributedString(string: tv.text ?? "")
        // Derive plain text (strip attachments) while collecting images to migrate
        var plainBuilder = ""
        var usedFileIDs = Set<String>()
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
            if let att = attrs[.attachment] as? InteractiveTextAttachment {
                // Convert attachment to file-based storage if not already
                if let data = att.imageData ?? att.fileData, let noteRef = att.note {
                    let mime: String
                    if let d = att.imageData, d.count > 4 && d.prefix(4) == Data([0x47,0x49,0x46,0x38]) { mime = "image/gif" } else if att.imageData != nil { mime = "image/jpeg" } else { mime = "application/octet-stream" }
                    let ext = mime.contains("gif") ? "gif" : (mime.contains("jpeg") ? "jpg" : "bin")
                    // Only store if not already present
                    if att.attachmentID == nil { att.attachmentID = UUID().uuidString }
                    if !noteRef.fileAttachmentIDs.contains(att.attachmentID!) {
                        if let saved = AttachmentFileStore.saveAttachment(note: noteRef, data: data, type: mime, preferredExt: ext) {
                            // Link attachmentID to archived interactive attachment
                            att.attachmentID = saved.id
                        }
                    }
                    if let id = att.attachmentID { usedFileIDs.insert(id) }
                }
                // Represent in plain text as placeholder token (not user-visible directly)
                plainBuilder.append("\n")
            } else {
                let substring = (attributed.string as NSString).substring(with: range)
                plainBuilder.append(substring)
            }
        }
        let lines = plainBuilder.components(separatedBy: "\n")
        note.title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        note.content = lines.dropFirst().joined(separator: "\n")
        note.previewExcerpt = String(note.content.prefix(240))
        // Archive rich text
    note.richTextData = RichTextArchiver.archive(attributed)
    (tv as? NativeTextView)?.reconcileFileAttachments()
        note.updateModifiedDate()
    NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
        
        do {
            try modelContext.save()
            hasChanges = false
            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
        }
    }
    
    private func saveIfNeeded() {
    if hasChanges { saveNote() }
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
    
    private func handleGiphySelection(_ gifData: Data) {
        guard let nativeTextView = textView as? NativeTextView,
              let image = UIImage(data: gifData) else { return }
        
        nativeTextView.insertInlineImage(image, data: gifData)
    }
}

enum TextStyle {
    case title, heading, subheading, body
    
    var font: UIFont {
        switch self {
        case .title: return .systemFont(ofSize: 24, weight: .bold)
        case .heading: return .systemFont(ofSize: 22, weight: .semibold)
        case .subheading: return .systemFont(ofSize: 21, weight: .medium)
        case .body: return .systemFont(ofSize: 20, weight: .regular)
        }
    }
}

struct NativeTextCanvas: UIViewRepresentable {
    let note: Note
    @Binding var textView: UITextView?
    @Binding var hasChanges: Bool
    @Binding var selectedTextStyle: TextStyle
    let modelContext: ModelContext
    
    func makeUIView(context: Context) -> NativeTextView {
        let textView = NativeTextView()
        textView.delegate = context.coordinator
        textView.note = note
        textView.hasChangesBinding = $hasChanges
        textView.modelContext = modelContext

        // One-time migration of legacy inline attachments Data -> file-based
        if !note.legacyMigrationDone && !note.attachments.isEmpty {
            for (idx, data) in note.attachments.enumerated() {
                guard idx < note.attachmentTypes.count else { continue }
                let type = note.attachmentTypes[idx]
                let ext: String
                if type.contains("gif") { ext = "gif" }
                else if type.contains("png") { ext = "png" }
                else { ext = "jpg" }
                _ = AttachmentFileStore.saveAttachment(note: note, data: data, type: type, preferredExt: ext)
            }
            note.attachments.removeAll()
            note.attachmentTypes.removeAll()
            note.attachmentIDs.removeAll()
            note.legacyMigrationDone = true
            try? modelContext.save()
        }
        
        // Native iOS text view setup - no borders, larger text
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 20, weight: .regular) // Increased from 17
        textView.textColor = .label // Dynamic color for light/dark mode
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.allowsEditingTextAttributes = true
        
        // Set consistent typing attributes for all text
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
        
        // Load archived rich text if present; fallback to plain text
        if let data = note.richTextData, let archived = RichTextArchiver.unarchive(data) {
            let mutable = NSMutableAttributedString(attributedString: archived)
            // Standardize attributes & upgrade attachments
            upgradeAndNormalizeLoadedAttachments(in: mutable, for: note)
            textView.attributedText = mutable
            // Start GIF animations after setting text
            textView.startGIFAnimations()
        } else {
            let fullText = note.title.isEmpty ? note.content : "\(note.title)\n\(note.content)"
            let mutable = NSMutableAttributedString(string: fullText, attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.label
            ])
            // Legacy inline attachment arrays support (temporary) - will be removed post migration
            textView.loadSavedAttachments(from: note, into: mutable)
            textView.attributedText = mutable
            textView.startGIFAnimations()
        }
        
        return textView
    }

    /// Normalize already archived inline image attachments (from loaded attributed text) to current device sizing rules.
    private func normalizeInlineAttachmentSizes(in textView: UITextView) {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let maxWidth: CGFloat = isPad ? 420 : 300
        let maxHeight: CGFloat = isPad ? 360 : 260
        textView.attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textView.attributedText.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            var bounds = attachment.bounds
            if bounds.width == 0 || bounds.height == 0 { return }
            let scale = min(1, min(maxWidth / bounds.width, maxHeight / bounds.height))
            if scale < 0.999 { // shrink only
                bounds.size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                attachment.bounds = bounds
            }
        }
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
        
        // Apply consistent body formatting to all text
        if !fullText.isEmpty {
            attributedText.addAttributes([
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.label
            ], range: NSRange(location: 0, length: fullText.count))
        }
        
        // Load saved attachments back into the text
        if let nativeTextView = textView as? NativeTextView {
            nativeTextView.loadSavedAttachments(from: note, into: attributedText)
        }
        
        textView.attributedText = attributedText
        
        // Format links only
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
                // Just format links, no title formatting
                nativeTextView.formatLinks()
                nativeTextView.scheduleDebouncedSave()
                nativeTextView.broadcastLivePreviewUpdate()
            }
        }
    }

    /// Rehydrate, scale, animate, and ID-bind loaded NSTextAttachments after unarchiving rich text.
    private func upgradeAndNormalizeLoadedAttachments(in mutable: NSMutableAttributedString, for note: Note) {
        let fullRange = NSRange(location: 0, length: mutable.length)
        // First normalize base attributes
        mutable.enumerateAttributes(in: fullRange) { attrs, range, _ in
            var newAttrs = attrs
            if newAttrs[.font] == nil { newAttrs[.font] = UIFont.systemFont(ofSize: 20, weight: .regular) }
            if newAttrs[.foregroundColor] == nil { newAttrs[.foregroundColor] = UIColor.label }
            mutable.setAttributes(newAttrs, range: range)
        }
        // Collect attachment ranges
        var attachmentRanges: [NSRange] = []
        mutable.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            if value is NSTextAttachment { attachmentRanges.append(range) }
        }
        guard !attachmentRanges.isEmpty else { return }
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let maxWidth: CGFloat = isPad ? 520 : 320
        let minWidth: CGFloat = isPad ? 180 : 120
        let maxHeight: CGFloat = isPad ? 320 : 220
        // Map existing file attachment metadata in order
        let count = min(attachmentRanges.count, note.fileAttachmentIDs.count)
        for i in 0..<count {
            let range = attachmentRanges[i]
            guard let old = mutable.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment else { continue }
            // Load corresponding file data
            let id = note.fileAttachmentIDs[i]
            let type = i < note.fileAttachmentTypes.count ? note.fileAttachmentTypes[i] : "image/jpeg"
            let fileName = i < note.fileAttachmentNames.count ? note.fileAttachmentNames[i] : ""
            var data: Data? = nil
            if let dir = AttachmentFileStore.noteDir(noteID: note.id), !fileName.isEmpty {
                let url = dir.appendingPathComponent(fileName)
                data = try? Data(contentsOf: url)
            }
            // Build interactive attachment
            let newAttachment = InteractiveTextAttachment()
            newAttachment.note = note
            newAttachment.attachmentID = id
            if type.hasPrefix("image"), let d = data {
                // GIF support
                if type == "image/gif", let animated = animatedImage(fromGIFData: d) {
                    newAttachment.image = animated
                } else if let img = UIImage(data: d) {
                    newAttachment.image = img
                } else if let img = old.image { // fallback
                    newAttachment.image = img
                }
                newAttachment.imageData = d
            } else if let img = old.image {
                newAttachment.image = img
            }
            // Determine intrinsic size
            var size = newAttachment.image?.size ?? old.image?.size ?? CGSize(width: 200, height: 200)
            // Scale
            if size.width > maxWidth || size.height > maxHeight {
                let scale = min(maxWidth / max(size.width, 1), maxHeight / max(size.height, 1))
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
            if size.width < minWidth { // upscale very small icons
                let scale = minWidth / max(size.width, 1)
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
            newAttachment.bounds = CGRect(x: 0, y: -5, width: size.width, height: size.height)
            // Replace in attributed string
            let replacement = NSAttributedString(attachment: newAttachment)
            mutable.replaceCharacters(in: range, with: replacement)
        }
    }
}

class NativeTextView: UITextView, UITextViewDelegate {
    var note: Note?
    var hasChangesBinding: Binding<Bool>?
    var modelContext: ModelContext?
    private var debounceInterval: TimeInterval { 0.6 }
    private var lastScheduledItemKey = "LNTextSaveWorkItem"
    private static var workItems: [String: DispatchWorkItem] = [:]
    
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
                
                // Only handle delete button taps, not general attachment taps
                if attachment.handleTap(at: attachmentLocation, in: self) {
                    return // Tap was handled by delete button
                }
                // Don't return here - let normal text editing continue
            }
            
            // Check if tap is on a link
            if let link = attributedText.attribute(.link, at: characterIndex, effectiveRange: nil) as? String {
                showLinkPreview(for: link, at: NSRange(location: characterIndex, length: 1))
                return
            }
        }
        
        // Allow normal UITextView tap handling for cursor positioning
        // Don't interfere with normal text editing
    }

    // Prune file-based attachments that were removed from the text (image runs deleted)
    func reconcileFileAttachments() {
        guard let note else { return }
        // Collect IDs present in current attributed text
        var presentIDs: Set<String> = []
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment, let id = att.attachmentID { presentIDs.insert(id) }
        }
        // Remove any fileAttachmentIDs not present
        let existing = note.fileAttachmentIDs
        for id in existing where !presentIDs.contains(id) {
            note.removeFileAttachment(id: id)
        }
    }

    func scheduleDebouncedSave() {
        guard let binding = hasChangesBinding, binding.wrappedValue, let note else { return }
        let key = note.id.uuidString
        // Cancel previous
        if let existing = NativeTextView.workItems[key] { existing.cancel() }
        let item = DispatchWorkItem { [weak self] in
            guard let self, let ctx = self.modelContext else { return }
            // Perform lightweight incremental save (archive + preview + thumbs if new attachments)
            let attributed = self.attributedText ?? NSAttributedString(string: self.text ?? "")
            note.richTextData = RichTextArchiver.archive(attributed)
            // Update preview excerpt quickly
            note.previewExcerpt = String((note.content).prefix(240))
            self.reconcileFileAttachments()
            try? ctx.save()
            NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
        }
        NativeTextView.workItems[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    func broadcastLivePreviewUpdate() {
        guard let note else { return }
        NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
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
    let newID = UUID().uuidString
    attachment.attachmentID = newID
        
    // Responsive scaling: wider on iPad, slightly narrower on iPhone
    let idiom = UIDevice.current.userInterfaceIdiom
    let imageSize = image.size
    let maxWidth: CGFloat = (idiom == .pad ? 520 : 320)
    let minWidth: CGFloat = (idiom == .pad ? 180 : 120)
    let maxHeight: CGFloat = (idiom == .pad ? 320 : 220)
        
        var newWidth = imageSize.width
        var newHeight = imageSize.height
        
        // Scale down if too large
        if newWidth > maxWidth || newHeight > maxHeight {
            let widthScale = maxWidth / newWidth
            let heightScale = maxHeight / newHeight
            let scale = min(widthScale, heightScale)
            newWidth *= scale
            newHeight *= scale
        }
        
        // Scale up if too small
        if newWidth < minWidth {
            let scale = minWidth / newWidth
            newWidth *= scale
            newHeight *= scale
        }
        
    attachment.bounds = CGRect(x: 0, y: -5, width: newWidth, height: newHeight)
        
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
        
    // Persist into note model - determine type based on data
    let isGIF = data.count > 4 && data.subdata(in: 0..<4) == Data([0x47, 0x49, 0x46, 0x38])
    let imageType = isGIF ? "image/gif" : "image/jpeg"
        hasChangesBinding?.wrappedValue = true
        if let modelNote = attachment.note ?? self.note {
            // Store file-based (preferred) & keep legacy arrays for now (migration step later)
            if let saved = AttachmentFileStore.saveAttachment(note: modelNote, data: data, type: imageType, preferredExt: imageType == "image/gif" ? "gif" : "jpg") {
                attachment.attachmentID = saved.id
                NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: modelNote)
            }
        }
    // Configure GIF animation (after saving so we know ID)
    if isGIF { attachment.configureGIFAnimation(with: data, in: self) }
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
    
    func loadSavedAttachments(from note: Note, into attributedText: NSMutableAttributedString) {
        // Restore saved images/GIFs to the editor
        for (index, attachmentData) in note.attachments.enumerated() {
            guard index < note.attachmentTypes.count else { continue }
            
            let attachmentType = note.attachmentTypes[index]
            
            if attachmentType.hasPrefix("image/") {
                if let image = UIImage(data: attachmentData) {
                    let attachment = InteractiveTextAttachment()
                    attachment.image = image
                    attachment.note = note
                    attachment.imageData = attachmentData
                    
                    // Use consistent sizing logic
                    let imageSize = image.size
                    let maxWidth: CGFloat = 300 // Fixed max width
                    let minWidth: CGFloat = 120
                    let maxHeight: CGFloat = 200
                    
                    var newWidth = imageSize.width
                    var newHeight = imageSize.height
                    
                    if newWidth > maxWidth || newHeight > maxHeight {
                        let widthScale = maxWidth / newWidth
                        let heightScale = maxHeight / newHeight
                        let scale = min(widthScale, heightScale)
                        newWidth *= scale
                        newHeight *= scale
                    }
                    
                    if newWidth < minWidth {
                        let scale = minWidth / newWidth
                        newWidth *= scale
                        newHeight *= scale
                    }
                    
                    attachment.bounds = CGRect(x: 0, y: -5, width: newWidth, height: newHeight)
                    
                    let attachmentString = NSAttributedString(attachment: attachment)
                    
                    // Add to end of text with proper spacing
                    if attributedText.length > 0 {
                        attributedText.append(NSAttributedString(string: "\n"))
                    }
                    attributedText.append(attachmentString)
                    attributedText.append(NSAttributedString(string: "\n"))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Removed complex title formatting - spatial view handles title display
    
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
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
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
        
        // Always use consistent body font
        let insertion = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
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
    var attachmentID: String?
    // GIF animation support
    fileprivate var gifFrames: [UIImage] = []
    fileprivate var gifDurations: [Double] = []
    fileprivate var gifTotalDuration: Double = 0
    fileprivate var gifDisplayLink: CADisplayLink?
    fileprivate var gifCurrentIndex: Int = 0
    fileprivate weak var hostingTextView: UITextView?
    fileprivate var gifAccumulated: Double = 0
    
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
        // Check if tap is on delete button (only in top-right corner)
        let deleteButtonFrame = CGRect(
            x: bounds.width - 32,
            y: 8,
            width: 24,
            height: 24
        )
        
        // Only handle delete button taps, ignore other taps on image
        if deleteButtonFrame.contains(point) {
            deleteAttachment(from: textView)
            return true // Tap was handled
        }
        
        // Return false for all other taps to allow normal text editing
        return false
    }
    
    private func deleteAttachment(from textView: UITextView) {
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        // Find and remove this attachment from text
        mutableText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableText.length)) { value, range, stop in
            if let attachment = value as? InteractiveTextAttachment, attachment === self {
                mutableText.deleteCharacters(in: range)
                stop.pointee = true
            }
        }
        
        textView.attributedText = mutableText
        
        // Update UI
        if let note = self.note {
            // Remove matching data (if any) from note model so it doesn't persist/preview
            if let data = self.imageData, let idx = note.attachments.firstIndex(of: data) {
                note.removeAttachment(at: idx)
            }
            NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
        }
        if let nativeTextView = textView as? NativeTextView {
            nativeTextView.hasChangesBinding?.wrappedValue = true
        }
    }

    fileprivate func configureGIFAnimation(with data: Data, in textView: UITextView) {
        hostingTextView = textView
        extractGIFFrames(data: data)
        startGIFIfNeeded()
    }
    
    private func extractGIFFrames(data: Data) {
        gifFrames.removeAll(); gifDurations.removeAll(); gifTotalDuration = 0; gifCurrentIndex = 0; gifAccumulated = 0
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return }
        var total: Double = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let duration = gifFrameDuration(source: source, index: i)
            gifFrames.append(UIImage(cgImage: cg))
            gifDurations.append(duration)
            total += duration
        }
        gifTotalDuration = total
        if let first = gifFrames.first { self.image = first }
    }
    
    private func startGIFIfNeeded() {
        guard gifFrames.count > 1, gifDisplayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(stepGIF(_:)))
        gifDisplayLink = link
        link.add(to: .main, forMode: .common)
    }
    
    @objc private func stepGIF(_ link: CADisplayLink) {
        guard gifFrames.count > 1 else { return }
        gifAccumulated += link.duration
        // Advance frames while accumulated > current frame duration (handle slow frames)
        while gifAccumulated > gifDurations[gifCurrentIndex] {
            gifAccumulated -= gifDurations[gifCurrentIndex]
            gifCurrentIndex = (gifCurrentIndex + 1) % gifFrames.count
            self.image = gifFrames[gifCurrentIndex]
            // Trigger redraw for attachment range
            if let tv = hostingTextView, let lm = tv.layoutManager as NSLayoutManager? {
                // Invalidate display for entire text to keep simple
                lm.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: tv.attributedText.length))
            }
        }
    }
    
    deinit {
        gifDisplayLink?.invalidate()
    }
}

// MARK: - GIF Utilities
private func animatedImage(fromGIFData data: Data) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let frameCount = CGImageSourceGetCount(source)
    guard frameCount > 1 else { return UIImage(data: data) }
    var images: [UIImage] = []
    var duration: Double = 0
    for i in 0..<frameCount {
        guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
        let frameDuration = gifFrameDuration(source: source, index: i)
        duration += frameDuration
        images.append(UIImage(cgImage: cg))
    }
    if duration <= 0 { duration = Double(frameCount) * 0.08 }
    return UIImage.animatedImage(with: images, duration: duration)
}

private func gifFrameDuration(source: CGImageSource, index: Int) -> Double {
    guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
          let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
    let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
    let clamped = gifDict[kCGImagePropertyGIFDelayTime] as? Double
    let val = unclamped ?? clamped ?? 0.1
    return val < 0.02 ? 0.02 : val
}

extension NativeTextView {
    // Enumerate attachments and start GIF animations post-load
    func startGIFAnimations() {
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment, let data = att.imageData, att.gifFrames.isEmpty {
                // Determine if data is GIF
                if data.count > 4 && data.subdata(in: 0..<4) == Data([0x47,0x49,0x46,0x38]) {
                    att.configureGIFAnimation(with: data, in: self)
                }
            }
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

// GIF picker now uses GiphyPicker from Components

#Preview {
    let note = Note(title: "Sample", content: "Content")
    NativeNoteEditor(note: note)
        .modelContainer(for: [Note.self], inMemory: true)
}