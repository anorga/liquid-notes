import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Photos
import ImageIO

struct NativeNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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
    @State private var showingSketchSheet = false
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var showingAISheet = false
    private let saveDebounceInterval: TimeInterval = 0.6
    
    // Reverted: no special iPad width; use full width content.
    private func optimalWidth(for geometry: GeometryProxy) -> CGFloat? { nil }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Native-feeling glass background
                    Color.clear
                        .nativeGlassBarBackground()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        nativeTopBar

                        if let maxWidth = optimalWidth(for: geometry) {
                            // iPad: centered wide column that resizes with window
                            HStack {
                                Spacer(minLength: 0)
                                NativeTextCanvas(
                                    note: note,
                                    textView: $textView,
                                    hasChanges: $hasChanges,
                                    selectedTextStyle: $selectedTextStyle,
                                    modelContext: modelContext
                                )
                                .frame(width: maxWidth, alignment: .topLeading)
                                Spacer(minLength: 0)
                            }
                        } else {
                            // iPhone or compact iPad - use full width
                            NativeTextCanvas(
                                note: note,
                                textView: $textView,
                                hasChanges: $hasChanges,
                                selectedTextStyle: $selectedTextStyle,
                                modelContext: modelContext
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        
                    }
                }
                // Floating, centered tool picker (iPad + iPhone) constrained within editor bounds.
                // The pill stays centered and fixed; only the contents scroll when overflowing.
                .overlay(alignment: .bottom) {
                    let w = geometry.size.width
                    let pillWidth = max(240, min(w - 48, 740))
                    HStack {
                        Spacer(minLength: 0)
                        ZStack {
                            Capsule()
                                .fill(.thinMaterial)
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.6))
                                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            ScrollView(.horizontal, showsIndicators: false) {
                                formattingToolbar
                                    .padding(.horizontal, 16)
                            }
                            .clipShape(Capsule())
                        }
                        .frame(width: pillWidth, height: 44)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 12)
                }
            }
            // Use system-provided glass on iOS 26+, fallback to material on older iOS
            .modifier(BottomBarCompatStyle())
            .navigationBarHidden(true)
            .toolbar { // Native keyboard toolbar for quick formatting/media actions
                ToolbarItemGroup(placement: .keyboard) {
                    Button { applyTextStyle(.title) } label: { Image(systemName: "textformat.size.larger") }
                    Button { (textView as? NativeTextView)?.formatBold() } label: { Image(systemName: "bold") }
                    Button { (textView as? NativeTextView)?.formatItalic() } label: { Image(systemName: "italic") }
                    Divider()
                    Button { (textView as? NativeTextView)?.insertBulletList() } label: { Image(systemName: "list.bullet") }
                    Button { (textView as? NativeTextView)?.insertNumberedList() } label: { Image(systemName: "list.number") }
                    Divider()
                    Button { showingPhotoPicker = true } label: { Image(systemName: "photo") }
                    Button { showingDocumentPicker = true } label: { Image(systemName: "doc") }
                    Button { showingSketchSheet = true } label: { Image(systemName: "pencil.and.outline") }
                }
            }
            .onAppear { 
                setupEditor()
                if let nativeTextView = textView as? NativeTextView {
                    nativeTextView.resumeGIFAnimations()
                }
            }
            .onDisappear { 
                saveIfNeeded()
                if let nativeTextView = textView as? NativeTextView {
                    nativeTextView.pauseGIFAnimations()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                saveIfNeeded()
            }
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
            .sheet(isPresented: $showingSketchSheet) {
                SketchSheet { image, data in
                    if let nativeTextView = textView as? NativeTextView {
                        nativeTextView.insertInlineImage(image, data: data)
                    }
                }
            }
            .sheet(isPresented: $showingAISheet) {
                NoteAISheet(note: note)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
                    .nativeGlassChip()
                    .foregroundStyle(.primary)
                    .fixedSize()
            }
            
            Button(action: { 
                showingDocumentPicker = true
            }) {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Button(action: { showingSketchSheet = true }) {
                Image(systemName: "pencil.and.outline")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
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

            Button(action: { showingAISheet = true }) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

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
        .padding(.horizontal, UI.Space.xl)
        .padding(.vertical, UI.Space.m)
        .nativeGlassBarBackground()
        .modifier(NavBarCompatStyle())
    }
    
    private func setupEditor() {
        isNewNote = note.title.isEmpty && note.content.isEmpty
        hasChanges = isNewNote
        // Listen for sketch insert requests from the text selection menu
        NotificationCenter.default.addObserver(forName: .lnRequestInsertSketch, object: nil, queue: .main) { _ in
            showingSketchSheet = true
        }
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
        // Tokenize & archive lightweight representation (no embedded binaries)
        let tokenized = RichTextArchiver.tokenizedAttributedString(from: attributed)
        if let data = RichTextArchiver.archiveTokenized(tokenized) {
            let hash = RichTextArchiver.computeHash(data: data)
            if hash != note.richTextHash {
                note.richTextData = data
                note.richTextHash = hash
            }
        }
        (tv as? NativeTextView)?.reconcileFileAttachments()
        note.updateModifiedDate()
    NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
        
        do {
            try modelContext.save()
            hasChanges = false
            HapticManager.shared.success()
            // Refresh widget data after saving note content
            SharedDataManager.shared.refreshWidgetData(context: modelContext)
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

// MARK: - Bar Styling (iOS compatibility)
private struct BottomBarCompatStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .toolbarBackground(.automatic, for: .bottomBar)
                    .toolbarBackgroundVisibility(.automatic, for: .bottomBar)
            } else {
                content
                    .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
                    .toolbarBackgroundVisibility(.visible, for: .bottomBar)
            }
        }
    }
}

private struct NavBarCompatStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .toolbarBackground(.automatic, for: .navigationBar)
                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            } else {
                content
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            }
        }
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
        textView.font = .systemFont(ofSize: 20, weight: .regular) // Larger for readability
        textView.textColor = .label // Dynamic color for light/dark mode
        
        // Responsive insets based on device (original values)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let horizontalInset: CGFloat = isIPad ? 40 : 20
        let verticalInset: CGFloat = isIPad ? 24 : 16
        textView.textContainerInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
        // No additional content inset (original sizing)
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        
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
            let containsTokens = archived.string.contains(RichTextArchiver.attachmentTokenPrefix) || archived.string.contains("[[CHECKBOX:")
            let rebuilt = containsTokens ? RichTextArchiver.rebuildFromTokens(note: note, tokenized: archived) : archived
            let mutable = NSMutableAttributedString(attributedString: rebuilt)
            upgradeAndNormalizeLoadedAttachments(in: mutable, for: note, textView: textView)
            textView.attributedText = mutable
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
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        func textViewDidChange(_ textView: UITextView) {
            if let nativeTextView = textView as? NativeTextView {
                nativeTextView.hasChangesBinding?.wrappedValue = true
                nativeTextView.scheduleDebouncedSave()
                nativeTextView.broadcastLivePreviewUpdate()
            }
        }
    }

    /// Rehydrate, scale, animate, and ID-bind loaded NSTextAttachments after unarchiving rich text.
    private func upgradeAndNormalizeLoadedAttachments(in mutable: NSMutableAttributedString, for note: Note, textView: UITextView) {
        let fullRange = NSRange(location: 0, length: mutable.length)
        // First normalize base attributes
        mutable.enumerateAttributes(in: fullRange) { attrs, range, _ in
            var newAttrs = attrs
            if newAttrs[.font] == nil { newAttrs[.font] = UIFont.systemFont(ofSize: 20, weight: .regular) }
            if newAttrs[.foregroundColor] == nil { newAttrs[.foregroundColor] = UIColor.label }
            mutable.setAttributes(newAttrs, range: range)
        }
        
        // Set textView reference for any checkboxes
        mutable.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            if let checkbox = value as? CheckboxTextAttachment {
                checkbox.textView = textView
            }
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
            let id = note.fileAttachmentIDs[i]
            let type = i < note.fileAttachmentTypes.count ? note.fileAttachmentTypes[i] : "image/jpeg"
            let fileName = i < note.fileAttachmentNames.count ? note.fileAttachmentNames[i] : ""

            // Build interactive attachment without blocking for I/O
            let newAttachment = InteractiveTextAttachment()
            newAttachment.note = note
            newAttachment.attachmentID = id

            // Use any existing image immediately to avoid stalls
            if let img = old.image { newAttachment.image = img }

            // Set an initial size from available image or a placeholder
            var size = newAttachment.image?.size ?? CGSize(width: 200, height: 200)
            if size.width > maxWidth || size.height > maxHeight {
                let scale = min(maxWidth / max(size.width, 1), maxHeight / max(size.height, 1))
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
            if size.width < minWidth {
                let scale = minWidth / max(size.width, 1)
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
            newAttachment.bounds = CGRect(x: 0, y: -5, width: size.width, height: size.height)

            // Replace inline immediately
            let replacement = NSAttributedString(attachment: newAttachment)
            mutable.replaceCharacters(in: range, with: replacement)

            // Load actual file data off the main thread and update the attachment when ready
            if let dir = AttachmentFileStore.noteDir(noteID: note.id), !fileName.isEmpty, type.hasPrefix("image") {
                let url = dir.appendingPathComponent(fileName)
                DispatchQueue.global(qos: .userInitiated).async { [weak textView] in
                    autoreleasepool {
                    guard let data = try? Data(contentsOf: url) else { return }
                    var nextImage: UIImage? = nil
                    if type == "image/gif", let animated = animatedImage(fromGIFData: data) { nextImage = animated }
                    else { nextImage = UIImage(data: data) }
                    guard let img = nextImage else { return }
                    // Compute scaled bounds
                    var scaled = img.size
                    if scaled.width > maxWidth || scaled.height > maxHeight {
                        let scale = min(maxWidth / max(scaled.width, 1), maxHeight / max(scaled.height, 1))
                        scaled = CGSize(width: scaled.width * scale, height: scaled.height * scale)
                    }
                    if scaled.width < minWidth {
                        let scale = minWidth / max(scaled.width, 1)
                        scaled = CGSize(width: scaled.width * scale, height: scaled.height * scale)
                    }
                    DispatchQueue.main.async {
                        newAttachment.image = img
                        newAttachment.imageData = data
                        newAttachment.bounds = CGRect(x: 0, y: -5, width: scaled.width, height: scaled.height)
                        textView?.setNeedsDisplay()
                    }
                    }
                }
            }
        }
    }
}

class NativeTextView: UITextView, UITextViewDelegate {
    var note: Note?
    var hasChangesBinding: Binding<Bool>?
    var modelContext: ModelContext?
    private var debounceInterval: TimeInterval {
        // Slow down autosave shortly after media insertion
        var base: TimeInterval = 0.6
        if Date().timeIntervalSince(recentMediaInsertionDate) < 2 { base = 1.5 }
        // Scale with document length to avoid heavy work during rapid typing on large notes
        let len = attributedText?.length ?? 0
        if len > 10_000 { base = max(base, 1.4) }
        else if len > 5_000 { base = max(base, 1.0) }
        return base
    }
    private var recentMediaInsertionDate: Date = .distantPast
    private var lastScheduledItemKey = "LNTextSaveWorkItem"
    private static var workItems: [String: DispatchWorkItem] = [:]
    // Save rate limiting
    private let minimumSaveSpacing: TimeInterval = 2.0
    private var lastSavedAt: CFTimeInterval = 0
    // Attachment change gating for preview broadcasts
    fileprivate var attachmentsMutated: Bool = false
    
    @objc func requestInsertSketch() {
        NotificationCenter.default.post(name: .lnRequestInsertSketch, object: nil)
    }
    
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
        // Add iOS 16+ edit menu interaction for Sketch action
        if #available(iOS 16.0, *) {
            let interaction = UIEditMenuInteraction(delegate: self)
            addInteraction(interaction)
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Check if tap is on an attachment
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if characterIndex < attributedText.length {
            // Check for checkbox first
            if let checkbox = attributedText.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? CheckboxTextAttachment {
                checkbox.toggle()
                
                // Force refresh by rebuilding the attributed string to ensure visual update
                let mutableText = NSMutableAttributedString(attributedString: attributedText)
                
                // Find the checkbox and replace it with updated version
                mutableText.enumerateAttribute(.attachment, in: NSRange(location: characterIndex, length: 1), options: []) { value, range, stop in
                    if let cb = value as? CheckboxTextAttachment, cb === checkbox {
                        // Create new attachment string with updated checkbox
                        let newCheckboxString = NSAttributedString(attachment: checkbox)
                        mutableText.replaceCharacters(in: range, with: newCheckboxString)
                        stop.pointee = true
                    }
                }
                
                // Apply the changes
                let currentSelection = selectedRange
                attributedText = mutableText
                selectedRange = currentSelection
                
                return
            }
            
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
            
        }
        
        // Allow normal UITextView tap handling for cursor positioning
        // Don't interfere with normal text editing
    }

    // Prune file-based attachments that were removed from the text (image runs deleted)
    @MainActor
    func reconcileFileAttachments() {
        guard let note else { return }
        // Collect IDs present in current attributed text
        var presentIDs: Set<String> = []
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment, let id = att.attachmentID { presentIDs.insert(id) }
        }
        // Remove any fileAttachmentIDs not present
        let existing = note.fileAttachmentIDs
        var removed = false
        for id in existing where !presentIDs.contains(id) {
            note.removeFileAttachment(id: id)
            removed = true
        }
        if removed { attachmentsMutated = true }
    }

    func scheduleDebouncedSave() {
        guard let binding = hasChangesBinding, binding.wrappedValue, let note else { return }
        let key = note.id.uuidString
        // Cancel previous
        if let existing = NativeTextView.workItems[key] { existing.cancel() }
        let item = DispatchWorkItem { [weak self] in
            guard let self, let ctx = self.modelContext else { return }
            // Enforce minimum spacing between heavy saves
            let now = CACurrentMediaTime()
            let delta = now - self.lastSavedAt
            if delta < self.minimumSaveSpacing {
                let delay = self.minimumSaveSpacing - delta
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.scheduleDebouncedSave()
                }
                return
            }
            self.lastSavedAt = now
            let attributed = self.attributedText ?? NSAttributedString(string: self.text ?? "")
            // Extract plain text quickly (skip attachments replaced by newline)
            var plainBuilder = ""
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                if attrs[.attachment] == nil {
                    plainBuilder.append((attributed.string as NSString).substring(with: range))
                } else {
                    plainBuilder.append("\n")
                }
            }
            let lines = plainBuilder.components(separatedBy: "\n")
            note.title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            note.content = lines.dropFirst().joined(separator: "\n")
            note.previewExcerpt = String(note.content.prefix(240))
            self.reconcileFileAttachments()
            note.updateModifiedDate()
            let tokenized = RichTextArchiver.tokenizedAttributedString(from: attributed)
            DispatchQueue.global(qos: .utility).async {
                if let data = RichTextArchiver.archiveTokenized(tokenized) {
                    let hash = RichTextArchiver.computeHash(data: data)
                    DispatchQueue.main.async {
                        if hash != note.richTextHash { note.richTextData = data; note.richTextHash = hash }
                        try? ctx.save()
                        // Only broadcast if attachments changed recently
                        if self.attachmentsMutated {
                            NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
                            self.attachmentsMutated = false
                        }
                    }
                }
            }
        }
        NativeTextView.workItems[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    func broadcastLivePreviewUpdate() {
        guard let note else { return }
        // Throttle and gate: only broadcast on attachment mutations or after longer idle window
        let now = CACurrentMediaTime()
        let minInterval: CFTimeInterval = attachmentsMutated ? 0.5 : 1.5
        if now - lastBroadcastTime < minInterval { return }
        lastBroadcastTime = now
        NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: note)
        attachmentsMutated = false
    }

    private var lastBroadcastTime: CFTimeInterval = 0
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return super.canPerformAction(action, withSender: sender) || 
               action == #selector(requestInsertSketch) ||
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
        toggleListItem("• ")
    }
    
    @objc func insertNumberedList() {
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        if range.length > 0 {
            // Handle multi-line selection with proper numbering
            let text = mutableText.string as NSString
            var lineRanges: [NSRange] = []
            
            text.enumerateSubstrings(in: range, options: [.byLines, .localized]) { _, lineRange, _, _ in
                lineRanges.append(lineRange)
            }
            
            // Check if all lines already have numbered list format
            let numberedPattern = "^\\d+\\. "
            let regex = try? NSRegularExpression(pattern: numberedPattern)
            var allNumbered = true
            
            for lineRange in lineRanges {
                let lineText = text.substring(with: lineRange)
                let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLine.isEmpty {
                    let matches = regex?.matches(in: lineText, range: NSRange(location: 0, length: lineText.count)) ?? []
                    if matches.isEmpty {
                        allNumbered = false
                        break
                    }
                }
            }
            
            // Process lines in reverse order
            var totalLengthChange = 0
            var lineNumber = lineRanges.count
            
            for lineRange in lineRanges.reversed() {
                let lineText = text.substring(with: lineRange)
                let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !trimmedLine.isEmpty {
                    if allNumbered {
                        // Remove numbering
                        if let regex = regex {
                            let matches = regex.matches(in: lineText, range: NSRange(location: 0, length: lineText.count))
                            if let match = matches.first {
                                let deleteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                                mutableText.deleteCharacters(in: deleteRange)
                                totalLengthChange -= match.range.length
                            }
                        }
                    } else {
                        // Add numbering
                        let prefix = "\(lineNumber). "
                        let insertion = NSAttributedString(string: prefix, attributes: [
                            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                            .foregroundColor: UIColor.label
                        ])
                        mutableText.insert(insertion, at: lineRange.location)
                        totalLengthChange += prefix.count
                        lineNumber -= 1
                    }
                }
            }
            
            attributedText = mutableText
            let newLength = max(0, range.length + totalLengthChange)
            selectedRange = NSRange(location: range.location, length: newLength)
            hasChangesBinding?.wrappedValue = true
        } else {
            // Handle single line - check if it has numbering
            let line = getCurrentLine()
            let numberedPattern = "^\\d+\\. "
            if let regex = try? NSRegularExpression(pattern: numberedPattern) {
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: line.count))
                if !matches.isEmpty {
                    // Remove numbering
                    let lineStart = getCurrentLineRange().location
                    let deleteRange = NSRange(location: lineStart, length: matches[0].range.length)
                    mutableText.deleteCharacters(in: deleteRange)
                    attributedText = mutableText
                    selectedRange = NSRange(location: max(0, range.location - matches[0].range.length), length: 0)
                    hasChangesBinding?.wrappedValue = true
                    return
                }
            }
            // Add numbering
            toggleListItem("1. ")
        }
    }
    
    @objc func insertTaskList() {
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        if range.length > 0 {
            // Handle multi-line selection
            let text = mutableText.string as NSString
            var lineRanges: [NSRange] = []
            
            text.enumerateSubstrings(in: range, options: [.byLines, .localized]) { _, lineRange, _, _ in
                lineRanges.append(lineRange)
            }
            
            // Check if all lines already have checkbox
            var allHaveCheckbox = true
            for lineRange in lineRanges {
                var hasCheckbox = false
                mutableText.enumerateAttribute(.attachment, in: lineRange, options: []) { value, attachmentRange, _ in
                    if value is CheckboxTextAttachment && attachmentRange.location == lineRange.location {
                        hasCheckbox = true
                    }
                }
                let lineText = text.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !lineText.isEmpty && !hasCheckbox {
                    allHaveCheckbox = false
                    break
                }
            }
            
            // Process lines in reverse order
            var totalLengthChange = 0
            for lineRange in lineRanges.reversed() {
                let lineText = text.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !lineText.isEmpty {
                    if allHaveCheckbox {
                        // Remove checkbox
                        mutableText.enumerateAttribute(.attachment, in: lineRange, options: []) { value, attachmentRange, stop in
                            if value is CheckboxTextAttachment && attachmentRange.location == lineRange.location {
                                // Remove checkbox and space after it
                                let deleteLength = min(2, lineRange.length) // Checkbox + space
                                mutableText.deleteCharacters(in: NSRange(location: lineRange.location, length: deleteLength))
                                totalLengthChange -= deleteLength
                                stop.pointee = true
                            }
                        }
                    } else {
                        // Add checkbox
                        let checkbox = CheckboxTextAttachment()
                        checkbox.textView = self
                        let checkboxString = NSAttributedString(attachment: checkbox)
                        let spaceString = NSAttributedString(string: " ", attributes: [
                            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                            .foregroundColor: UIColor.label
                        ])
                        let insertion = NSMutableAttributedString()
                        insertion.append(checkboxString)
                        insertion.append(spaceString)
                        
                        mutableText.insert(insertion, at: lineRange.location)
                        totalLengthChange += insertion.length
                    }
                }
            }
            
            attributedText = mutableText
            let newLength = max(0, range.length + totalLengthChange)
            selectedRange = NSRange(location: range.location, length: newLength)
        } else {
            // Handle single line or cursor position
            let lineRange = getCurrentLineRange()
            var hasCheckbox = false
            
            // Check if line already has checkbox at start
            if lineRange.length > 0 {
                mutableText.enumerateAttribute(.attachment, in: lineRange, options: []) { value, attachmentRange, stop in
                    if value is CheckboxTextAttachment && attachmentRange.location == lineRange.location {
                        hasCheckbox = true
                        stop.pointee = true
                    }
                }
            }
            
            if hasCheckbox {
                // Remove checkbox and space
                let deleteLength = min(2, lineRange.length)
                mutableText.deleteCharacters(in: NSRange(location: lineRange.location, length: deleteLength))
                attributedText = mutableText
                selectedRange = NSRange(location: max(0, range.location - deleteLength), length: 0)
            } else {
                // Add checkbox
                let line = getCurrentLine()
                let checkbox = CheckboxTextAttachment()
                checkbox.textView = self
                let checkboxString = NSAttributedString(attachment: checkbox)
                let spaceString = NSAttributedString(string: " ", attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                    .foregroundColor: UIColor.label
                ])
                
                let insertion = NSMutableAttributedString()
                if !line.isEmpty && range.location != lineRange.location {
                    insertion.append(NSAttributedString(string: "\n"))
                }
                insertion.append(checkboxString)
                insertion.append(spaceString)
                
                let insertLocation = line.isEmpty ? range.location : (range.location == lineRange.location ? lineRange.location : range.location)
                mutableText.insert(insertion, at: insertLocation)
                attributedText = mutableText
                selectedRange = NSRange(location: insertLocation + insertion.length, length: 0)
            }
        }
        
        hasChangesBinding?.wrappedValue = true
    }
    
    @objc func insertDashedList() {
        toggleListItem("– ")
    }
    
    @objc func insertBlockQuote() {
        toggleListItem("> ")
    }
    
    @objc func insertDivider() {
        insertText("\n---\n")
    }
    
    // MARK: - Media
    
    // Media insertion handled by SwiftUI toolbar, not context menu
    
    
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
    let isPNG = data.count > 4 && data.subdata(in: 0..<4) == Data([0x89, 0x50, 0x4E, 0x47])
    let imageType = isGIF ? "image/gif" : (isPNG ? "image/png" : "image/jpeg")
        hasChangesBinding?.wrappedValue = true
        if let modelNote = attachment.note ?? self.note {
            AttachmentFileStore.saveAttachmentAsync(note: modelNote, data: data, type: imageType, preferredExt: (imageType == "image/gif" ? "gif" : (imageType == "image/png" ? "png" : "jpg"))) { id, _, _ in
                if let id { attachment.attachmentID = id }
                NotificationCenter.default.post(name: .lnNoteAttachmentsChanged, object: modelNote)
            }
        }
    if isGIF { attachment.configureGIFAnimation(with: data, in: self) }
    recentMediaInsertionDate = Date()
    attachmentsMutated = true
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
        attachmentsMutated = true
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
    
    private func toggleListItem(_ prefix: String) {
        let range = selectedRange
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        if range.length > 0 {
            // Handle multi-line selection
            let text = mutableText.string as NSString
            var lineRanges: [NSRange] = []
            
            // Enumerate all line ranges that intersect with the selection
            text.enumerateSubstrings(in: range, options: [.byLines, .localized]) { _, lineRange, _, _ in
                lineRanges.append(lineRange)
            }
            
            // Check if all non-empty lines already have the prefix
            var allHavePrefix = true
            for lineRange in lineRanges {
                let lineText = text.substring(with: lineRange)
                let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLine.isEmpty && !lineText.hasPrefix(prefix) {
                    allHavePrefix = false
                    break
                }
            }
            
            // Process lines in reverse order to maintain indices
            var totalLengthChange = 0
            for lineRange in lineRanges.reversed() {
                let lineText = text.substring(with: lineRange)
                let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !trimmedLine.isEmpty {
                    if allHavePrefix && lineText.hasPrefix(prefix) {
                        // Remove prefix
                        let newRange = NSRange(location: lineRange.location, length: prefix.count)
                        mutableText.deleteCharacters(in: newRange)
                        totalLengthChange -= prefix.count
                    } else if !lineText.hasPrefix(prefix) {
                        // Add prefix
                        let insertion = NSAttributedString(string: prefix, attributes: [
                            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                            .foregroundColor: UIColor.label
                        ])
                        mutableText.insert(insertion, at: lineRange.location)
                        totalLengthChange += prefix.count
                    }
                }
            }
            
            attributedText = mutableText
            // Adjust selection to account for changed text
            let newLength = max(0, range.length + totalLengthChange)
            selectedRange = NSRange(location: range.location, length: newLength)
        } else {
            // Handle single line or cursor position
            let line = getCurrentLine()
            if line.hasPrefix(prefix) {
                // Remove the prefix from current line
                let lineStart = getCurrentLineRange().location
                let deleteRange = NSRange(location: lineStart, length: prefix.count)
                mutableText.deleteCharacters(in: deleteRange)
                attributedText = mutableText
                selectedRange = NSRange(location: max(0, range.location - prefix.count), length: 0)
            } else {
                // Add prefix
                let insertText = line.isEmpty ? prefix : "\n" + prefix
                let insertion = NSAttributedString(string: insertText, attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                    .foregroundColor: UIColor.label
                ])
                mutableText.insert(insertion, at: range.location)
                attributedText = mutableText
                selectedRange = NSRange(location: range.location + insertText.count, length: 0)
            }
        }
        
        hasChangesBinding?.wrappedValue = true
    }
    
    private func getCurrentLineRange() -> NSRange {
        let text = self.text ?? ""
        let location = selectedRange.location
        guard location <= text.count else { return NSRange(location: 0, length: 0) }
        let nsText = text as NSString
        return nsText.lineRange(for: NSRange(location: location, length: 0))
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

@available(iOS 16.0, *)
extension NativeTextView: UIEditMenuInteractionDelegate {
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let sketch = UIAction(title: "Sketch", image: UIImage(systemName: "pencil.and.outline")) { [weak self] _ in
            self?.requestInsertSketch()
        }
        return UIMenu(children: [sketch] + suggestedActions)
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

// MARK: - Checkbox Text Attachment

class CheckboxTextAttachment: NSTextAttachment {
    var isChecked: Bool = false
    weak var textView: UITextView?
    
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        updateImage()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateImage()
    }
    
    func updateImage() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let symbolName = isChecked ? "checkmark.circle.fill" : "circle"
        let color = isChecked ? UIColor.systemBlue : UIColor.label
        
        if let symbolImage = UIImage(systemName: symbolName, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal) {
            self.image = symbolImage
            self.bounds = CGRect(x: 0, y: -4, width: 22, height: 22)
        }
    }
    
    func toggle() {
        isChecked.toggle()
        updateImage()
        
        // Trigger redraw and haptic feedback
        if let tv = textView {
            tv.setNeedsDisplay()
            
            // Mark as changed
            if let nativeTextView = tv as? NativeTextView {
                nativeTextView.hasChangesBinding?.wrappedValue = true
                // Add haptic feedback for better user experience
                HapticManager.impact(.light)
            }
        }
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
    
    fileprivate var compositeCache: UIImage?
    fileprivate var compositeCacheSize: CGSize = .zero
    
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        // Cache the composited overlay image at the requested size to avoid repeated redraws
        if let cached = compositeCache, compositeCacheSize.equalTo(imageBounds.size) { return cached }
        guard let baseImage = super.image(forBounds: imageBounds, textContainer: textContainer, characterIndex: charIndex) else { return image }
        let composited = addDeleteButton(to: baseImage)
        compositeCache = composited
        compositeCacheSize = imageBounds.size
        return composited
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
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        // Invalidate composite cache when size changes
        if !compositeCacheSize.equalTo(bounds.size) {
            compositeCache = nil
        }
        return bounds
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
            nativeTextView.attachmentsMutated = true
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
        
        link.preferredFramesPerSecond = 8
        
        if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
            return
        }
        
        gifDisplayLink = link
        link.add(to: .main, forMode: .common)
    }
    
    @objc private func stepGIF(_ link: CADisplayLink) {
        guard gifFrames.count > 1 else { return }
        
        if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
            gifDisplayLink?.invalidate()
            gifDisplayLink = nil
            return
        }
        
        gifAccumulated += link.duration
        let frameSkip = PerformanceOptimizer.shared.shouldReduceGIFFrameRate ? 1 : 1
        
        while gifAccumulated > gifDurations[gifCurrentIndex] * Double(frameSkip) {
            gifAccumulated -= gifDurations[gifCurrentIndex] * Double(frameSkip)
            gifCurrentIndex = (gifCurrentIndex + frameSkip) % gifFrames.count
            self.image = gifFrames[gifCurrentIndex]
            
            // CADisplayLink runs on main; invalidate display inline to avoid extra dispatch overhead
            if let tv = self.hostingTextView,
               let lm = tv.layoutManager as NSLayoutManager?,
               let full = tv.attributedText {
                let searchRange = NSRange(location: 0, length: full.length)
                var targetRange: NSRange?
                full.enumerateAttribute(.attachment, in: searchRange) { value, range, stop in
                    if let att = value as? InteractiveTextAttachment, att === self {
                        targetRange = range
                        stop.pointee = true
                    }
                }
                if let r = targetRange { lm.invalidateDisplay(forCharacterRange: r) }
            }
            break
        }
    }
    
    func pauseGIF() {
        gifDisplayLink?.isPaused = true
    }
    
    func resumeGIF() {
        gifDisplayLink?.isPaused = false
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
    func startGIFAnimations() {
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment, let data = att.imageData, att.gifFrames.isEmpty {
                if data.count > 4 && data.subdata(in: 0..<4) == Data([0x47,0x49,0x46,0x38]) {
                    att.configureGIFAnimation(with: data, in: self)
                }
            }
        }
    }
    
    func pauseGIFAnimations() {
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment {
                att.pauseGIF()
            }
        }
    }
    
    func resumeGIFAnimations() {
        attributedText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
            if let att = value as? InteractiveTextAttachment {
                att.resumeGIF()
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

struct NoteAISheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var isAnalyzing = false
    @State private var analysisComplete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if !note.suggestedTags.isEmpty {
                        suggestedTagsSection
                    } else if isAnalyzing {
                        analyzingSection
                    } else if !analysisComplete {
                        analyzeButton
                    }

                    if analysisComplete && note.suggestedTags.isEmpty {
                        noSuggestionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if note.suggestedTags.isEmpty && note.lastAnalyzedDate == nil {
                analyzeNote()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Note Intelligence")
                .font(.headline)

            Text("AI-powered suggestions based on your note content")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var suggestedTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested Tags", systemImage: "tag")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(Array(zip(note.suggestedTags.indices, note.suggestedTags)), id: \.0) { index, tag in
                    HStack(spacing: 6) {
                        Text(tag)
                            .font(.callout)

                        Button {
                            HapticManager.shared.success()
                            ModelMutationScheduler.shared.schedule {
                                note.acceptSuggestedTag(tag)
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Button {
                            HapticManager.shared.buttonTapped()
                            ModelMutationScheduler.shared.schedule {
                                note.dismissSuggestedTag(tag)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.purple.opacity(0.15), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 0.5))
                }
            }

            if !note.tags.isEmpty {
                Divider().padding(.vertical, 8)
                Label("Current Tags", systemImage: "tag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.blue.opacity(0.15)))
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private var analyzingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing note content...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var analyzeButton: some View {
        Button {
            analyzeNote()
        } label: {
            Label("Analyze Note", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var noSuggestionsSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundStyle(.green)
            Text("No suggestions needed")
                .font(.subheadline)
            Text("Your note is already well-organized")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }

    private func analyzeNote() {
        isAnalyzing = true
        let existingTags = note.tags

        NoteIntelligenceService.shared.analyzeNote(note) { tags, confidences in
            let filteredTags = tags.filter { !existingTags.contains($0) }
            ModelMutationScheduler.shared.schedule {
                note.suggestedTags = filteredTags
                note.tagConfidences = confidences
                note.lastAnalyzedDate = Date()
            }
            isAnalyzing = false
            analysisComplete = true
        }

        if note.contentEmbedding == nil {
            let text = "\(note.title) \(note.content)"
            let embedding = NoteIntelligenceService.shared.generateEmbedding(for: text)
            ModelMutationScheduler.shared.schedule {
                note.contentEmbedding = embedding
            }
        }
    }
}
