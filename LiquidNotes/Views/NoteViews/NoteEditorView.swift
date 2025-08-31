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
import ImageIO

struct NoteEditorView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Model
    let note: Note

    // Primary editing state
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var hasChanges = false
    @State private var isNewNote = false

    // Feature toggles / sheets
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingGiphyPicker = false
    @State private var showingTaskList = false
    @State private var showingTagEditor = false
    @State private var showingMetadata = false

    // Temp metadata editing
    @State private var tempTags: [String] = []
    @State private var tempDueDate: Date? = nil
    @State private var tempPriority: NotePriority = .normal

    // Focus & observers
    @State private var focusMode = false
    @State private var focusObserver: NSObjectProtocol?
    @State private var templateObserver: NSObjectProtocol?

    // Link autocomplete
    @State private var linkQuery: String = ""
    @State private var showLinkOverlay = false
    @State private var linkAnchorRect: CGRect = .zero
    @State private var activeTextView: UITextView? = nil

    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]

    var body: some View {
        ScrollView { editorContent }
            .padding(.bottom, 56)
            .safeAreaInset(edge: .top, spacing: 0) { 
                customToolbar
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .bottom)
            }
            .overlay(alignment: .topLeading) { linkOverlay }
            .background(LiquidNotesBackground().ignoresSafeArea())
            .onAppear { onAppearSetup() }
            .onDisappear { onDisappearCleanup() }
            .onChange(of: selectedPhoto) { _, newPhoto in
                guard let newPhoto else { return }
                loadPhotoData(from: newPhoto)
            }
            .sheet(isPresented: $showingGiphyPicker) { giphySheet }
    }

    // MARK: - Main content stack
    private var editorContent: some View {
        Group {
            VStack(spacing: 24) {
                titleAndBodyCard
                if showingMetadata && !focusMode { metadataSection }
                if showingTaskList && !focusMode { taskListSection }
                if showingTagEditor && !focusMode { tagEditorSection }
                if !note.attachments.isEmpty && !focusMode { attachmentsSection }
                BacklinksSection(currentNote: note, allNotes: allNotes)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                if !note.linkedNoteIDs.isEmpty {
                    LinkedForwardSection(currentNote: note, allNotes: allNotes)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Components
    private var titleAndBodyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleField
            Divider().opacity(0.25)
            richTextEditor
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .modernGlassCard()
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
    private var titleField: some View {
        TextField("Title", text: $title)
            .font(.title)
            .fontWeight(.semibold)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .onChange(of: title) { _, _ in hasChanges = true }
    }
    private var richTextEditor: some View {
        RichTextEditor(
            text: $content,
            attributedText: $attributedContent,
            placeholder: "Start typing...",
            onTextChanged: { hasChanges = true },
            onLinkTrigger: { query, rect, tv in
                linkQuery = query
                linkAnchorRect = rect
                activeTextView = tv
                showLinkOverlay = true
            },
            onLinkCancel: { showLinkOverlay = false }
        )
        .onChange(of: attributedContent) { _, _ in hasChanges = true }
        .onChange(of: content) { _, _ in hasChanges = true }
        .frame(minHeight: 240)
    }
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Meta", systemImage: "info.circle").font(.headline).fontWeight(.semibold)
                Spacer()
                Button(action: { withAnimation(.bouncy(duration: 0.3)) { showingMetadata = false } }) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 12) {
                // Due date
                HStack(spacing: 12) {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    DatePicker(
                        "Due Date",
                        selection: Binding(
                            get: { tempDueDate ?? Date() },
                            set: { new in tempDueDate = new; hasChanges = true }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    if tempDueDate != nil {
                        Button(role: .destructive) { tempDueDate = nil; hasChanges = true } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                // Priority
                HStack(spacing: 12) {
                    Image(systemName: tempPriority.iconName).foregroundStyle(tempPriority.color)
                    Picker("Priority", selection: $tempPriority) {
                        ForEach(NotePriority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                // Progress
                if !(note.tasks?.isEmpty ?? true) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            Circle().trim(from: 0, to: note.progress).stroke(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            Text(Int(note.progress * 100), format: .number).font(.caption).bold()
                        }
                        .frame(width: 38, height: 38)
                        VStack(alignment: .leading) {
                            Text("Completion").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(note.progress * 100))% done").font(.subheadline).fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .liquidGlassEffect(.thin, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    private var taskListSection: some View {
        TaskListView(
            tasks: Binding(
                get: { note.tasks ?? [] },
                set: { newVal in
                    note.tasks = newVal
                    note.updateProgress()
                    hasChanges = true
                }
            ),
            onToggle: { index in note.toggleTask(at: index); hasChanges = true },
            onDelete: { index in note.removeTask(at: index); hasChanges = true },
            onAdd: { text in note.addTask(text); hasChanges = true }
        )
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    private var tagEditorSection: some View {
        TagListView(
            tags: $tempTags,
            onAdd: { tag in note.addTag(tag); tempTags = note.tags; hasChanges = true },
            onRemove: { tag in note.removeTag(tag); tempTags = note.tags; hasChanges = true }
        )
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Attachments").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
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
    // Replaces NavigationStack toolbar (more reliable in sheet/presentation stacks)
    private var customToolbar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let ultraNarrow = width < 340
            HStack(spacing: 10) {
                cancelButtonCompact
                    .layoutPriority(2)
                // Scrollable action cluster ensures ends stay visible
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        iconButton(system: focusMode ? "eye.slash" : "eye", colors: [.teal, .blue], accessibilityLabel: focusMode ? "Exit Focus" : "Enter Focus") { withAnimation(.easeInOut) { focusMode.toggle() } }
                        iconButton(system: showingTaskList ? "checklist.checked" : "checklist", colors: showingTaskList ? [.green, .mint] : [.gray, .gray.opacity(0.6)], accessibilityLabel: showingTaskList ? "Hide Tasks" : "Show Tasks") { withAnimation(.bouncy(duration:0.3)) { showingTaskList.toggle() } }
                        iconButton(system: showingTagEditor ? "tag.fill" : "tag", colors: showingTagEditor ? [.purple, .pink] : [.gray, .gray.opacity(0.6)], accessibilityLabel: showingTagEditor ? "Hide Tags" : "Show Tags") { withAnimation(.bouncy(duration:0.3)) { showingTagEditor.toggle() } }
                        iconButton(system: "face.smiling", colors: [.blue, .cyan], accessibilityLabel: "Insert GIF") { showingGiphyPicker = true }
                        PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .livePhotos]), photoLibrary: .shared()) {
                            gradientIcon(system: "photo.badge.plus", colors: [.green, .mint])
                                .accessibilityLabel("Add Photo")
                        }
                        .buttonStyle(.plain)
                        if ultraNarrow {
                            Menu {
                                Button(action: { withAnimation(.bouncy(duration:0.3)) { showingMetadata.toggle() } }) { Label(showingMetadata ? "Hide Meta" : "Show Meta", systemImage: showingMetadata ? "info.circle.fill" : "info.circle") }
                            } label: {
                                gradientIcon(system: "ellipsis.circle", colors: [.secondary, .secondary.opacity(0.6)])
                                    .accessibilityLabel("More Actions")
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                            }
                        } else {
                            iconButton(system: showingMetadata ? "info.circle.fill" : "info.circle", colors: [.indigo, .purple], accessibilityLabel: showingMetadata ? "Hide Meta" : "Show Meta") { withAnimation(.bouncy(duration:0.3)) { showingMetadata.toggle() } }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)
                saveButtonCompact
                    .layoutPriority(2)
            }
            .frame(maxWidth: .infinity)
            .font(.title3)
            .imageScale(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .frame(height: 58)
    }
    // Compact versions to conserve horizontal space; original styling simplified
    private var cancelButtonCompact: some View {
        Button(action: { cancelEdit() }) {
            Text("Cancel")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel Editing")
    }
    private var saveButtonCompact: some View {
        let enabled = hasChanges || isNewNote
        return Button(action: { saveNote(); dismiss() }) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Save")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: enabled ? [Color.accentColor, Color.accentColor.opacity(0.65)] : [Color.secondary.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule()
            )
            .foregroundStyle(Color.white.opacity(enabled ? 1 : 0.7))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            .shadow(color: enabled ? Color.accentColor.opacity(0.3) : .clear, radius: 5, y: 2)
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .accessibilityLabel("Save Note")
        .animation(.easeInOut(duration: 0.25), value: hasChanges)
    }
    @ViewBuilder private func iconButton(system: String, colors: [Color], accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { gradientIcon(system: system, colors: colors) }
            .buttonStyle(.plain)
            .padding(8)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel(accessibilityLabel)
    }
    private func gradientIcon(system: String, colors: [Color]) -> some View {
        Image(systemName: system)
            .font(.title3)
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }
    private var giphySheet: some View {
        GiphyPicker(isPresented: $showingGiphyPicker) { gifData in
            note.addAttachment(data: gifData, type: "image/gif"); hasChanges = true
        }
    }
    private func onAppearSetup() {
        loadNoteData(); tempTags = note.tags; if !(note.tasks?.isEmpty ?? true) { showingTaskList = true }
        focusObserver = NotificationCenter.default.addObserver(forName: .lnToggleFocusMode, object: nil, queue: .main) { _ in withAnimation { focusMode.toggle() } }
        templateObserver = NotificationCenter.default.addObserver(forName: .lnInsertTemplate, object: nil, queue: .main) { _ in insertTemplate() }
    }
    private func onDisappearCleanup() {
        if let o = focusObserver { NotificationCenter.default.removeObserver(o) }
        if let o = templateObserver { NotificationCenter.default.removeObserver(o) }
    }
    private func loadNoteData() {
        let wasEmpty = note.title.isEmpty && note.content.isEmpty
        title = note.title
        content = note.content
        attributedContent = NSAttributedString(string: note.content)
        isNewNote = wasEmpty
    tempDueDate = note.dueDate
    tempPriority = note.priority
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hasChanges = self.isNewNote
        }
    }
    private func saveNote() {
    let previousTitle = note.title
    let previousContent = note.content
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
    note.recordTitleAlias(previousTitle: previousTitle, newTitle: trimmedTitle)
    note.title = trimmedTitle
        note.content = trimmedContent
    note.dueDate = tempDueDate
    note.priority = tempPriority
    if previousContent != trimmedContent { note.updateLinkedNoteTitles() }
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

private extension NoteEditorView {
    func insertTemplate() {
        let template = """
        ## Summary
        - 
        
        ## Key Points
        - 
        - 
        
        ## Next Actions
        - [ ] 
        """
        content = content + template
        hasChanges = true
    }
}

// MARK: - Link Overlay
private extension NoteEditorView {
    var filteredLinkCandidates: [Note] {
        let q = linkQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [Note]
        if q.isEmpty {
            base = Array(allNotes.filter { $0.id != note.id }.prefix(24))
        } else {
            base = allNotes.filter { $0.id != note.id && ($0.title.lowercased().contains(q) || $0.aliasTitles.contains { $0.lowercased().contains(q) }) }
        }
        // Rank: match score (prefix > contains) + recency + usage
        let now = Date()
        let scored = base.map { n -> (Note, Double) in
            let titleLower = n.title.lowercased()
            var score: Double = 0
            if !q.isEmpty {
                if titleLower.hasPrefix(q) { score += 30 }
                else if titleLower.contains(q) { score += 10 }
            } else { score += 2 }
            score += Double(min(n.linkUsageCount, 25)) * 0.8
            if let d = n.lastLinkedDate { let age = now.timeIntervalSince(d); score += max(0, 20 - age/3600) }
            return (n, score)
        }
        .sorted { $0.1 > $1.1 }
        return scored.prefix(8).map { $0.0 }
    }
    @ViewBuilder var linkOverlay: some View {
        if showLinkOverlay {
            VStack(alignment: .leading, spacing: 0) {
                if filteredLinkCandidates.isEmpty {
                    Button(action: { createAndInsertLink() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle").foregroundStyle(.green)
                            Text("Create note ‘\(linkQuery.trimmingCharacters(in: .whitespaces))’")
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(Color.secondary.opacity(0.07))
                }
                ForEach(filteredLinkCandidates, id: \.id) { candidate in
                    Button(action: { insertLink(candidate) }) {
                        HStack(spacing: 8) {
                            Image(systemName: candidate.isFavorited ? "star.fill" : "note.text")
                                .foregroundStyle(candidate.isFavorited ? .yellow : .secondary)
                            highlight(candidate.title.isEmpty ? "Untitled" : candidate.title)
                                .font(.callout).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color.secondary.opacity(0.07))
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            .padding(.top, max(0, linkAnchorRect.minY + 10))
            .padding(.leading, max(0, linkAnchorRect.minX + 10))
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: filteredLinkCandidates.count)
        }
    }
    func insertLink(_ target: Note) {
        guard let tv = activeTextView else { return }
        let insertion = (target.title.isEmpty ? "Untitled" : target.title) + "]]"
        if let range = tv.selectedTextRange {
            // Remove the currently typed partial token (from [[ ... to caret)
            let cursor = tv.offset(from: tv.beginningOfDocument, to: range.start)
            let ns = tv.text as NSString
            var start = cursor
            while start > 0 {
                let char = ns.character(at: start - 1)
                let scalar = UnicodeScalar(char)!
                if Character(scalar) == "[" { // crude: stop at first [
                    if start >= 2 && ns.substring(with: NSRange(location: start-2, length: 2)) == "[[" { start -= 2; break }
                }
                if Character(scalar).isWhitespace || Character(scalar) == "\n" { break }
                start -= 1
            }
            let replaceRange = NSRange(location: start, length: cursor - start)
            if let swiftRange = Range(replaceRange, in: tv.text) {
                let newText = (tv.text.replacingCharacters(in: swiftRange, with: "[[" + insertion))
                tv.text = newText
                parentUpdateFromTextView(tv)
                let newCursorPos = start + 2 + insertion.count
                if let position = tv.position(from: tv.beginningOfDocument, offset: newCursorPos) { tv.selectedTextRange = tv.textRange(from: position, to: position) }
            }
        }
        showLinkOverlay = false
        note.updateLinkedNoteTitles()
    target.linkUsageCount += 1
    target.lastLinkedDate = Date()
    }
    func createAndInsertLink() {
        let title = linkQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
    // Request creation of a new note with that title via notification
        // We need model context; easiest path: post notification with title to request creation
        NotificationCenter.default.post(name: .lnCreateAndLinkNoteRequested, object: title)
    }
    func highlight(_ title: String) -> Text {
        let q = linkQuery.lowercased()
        guard !q.isEmpty else { return Text(title) }
        let lower = title.lowercased()
        var idx = lower.startIndex
        var out = Text("")
        while idx < lower.endIndex {
            if let range = lower[idx...].range(of: q) {
                if range.lowerBound > idx { out = out + Text(String(title[idx..<range.lowerBound])) }
                out = out + Text(String(title[range])).foregroundStyle(Color.accentColor).fontWeight(.semibold)
                idx = range.upperBound
            } else {
                out = out + Text(String(title[idx...]))
                break
            }
        }
        return out
    }
    func parentUpdateFromTextView(_ tv: UITextView) {
        content = tv.text
        attributedContent = tv.attributedText
        hasChanges = true
    }
}

// Backlinks section component
struct BacklinksSection: View {
    let currentNote: Note
    let allNotes: [Note]
    @State private var expanded = false
    var referencing: [Note] {
        guard !currentNote.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let target = currentNote.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allNotes.filter { $0.id != currentNote.id && $0.linkedNoteTitles.map { $0.lowercased() }.contains(target) }
    }
    var body: some View {
        if !referencing.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Backlinks", systemImage: "link").font(.headline).fontWeight(.semibold)
                    Spacer()
                    Button(action: { withAnimation(.bouncy(duration: 0.35)) { expanded.toggle() } }) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                if expanded {
                    VStack(spacing: 8) {
                        ForEach(referencing, id: \.id) { note in
                            Button(action: {
                                // Broadcast an open-note request; parent container can listen.
                                NotificationCenter.default.post(name: .lnOpenNoteRequested, object: note.id)
                            }) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: note.isFavorited ? "star.fill" : "note.text")
                                        .font(.caption)
                                        .foregroundStyle(note.isFavorited ? .yellow : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        if !note.content.isEmpty {
                                            Text(note.content)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(16)
            .background(.clear)
            .premiumGlassCard()
        }
    }
}

struct LinkedForwardSection: View {
    let currentNote: Note
    let allNotes: [Note]
    @State private var expanded = true
    private var linked: [Note] { allNotes.filter { currentNote.linkedNoteIDs.contains($0.id) } }
    var body: some View {
        if !linked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Links", systemImage: "arrowshape.turn.up.right.circle").font(.headline).fontWeight(.semibold)
                    Spacer()
                    Button(action: { withAnimation(.bouncy(duration: 0.3)) { expanded.toggle() } }) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                if expanded {
                    VStack(spacing: 8) {
                        ForEach(linked, id: \.id) { note in
                            Button(action: { NotificationCenter.default.post(name: .lnOpenNoteRequested, object: note.id) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: note.isFavorited ? "star.fill" : "note.text")
                                        .font(.caption)
                                        .foregroundStyle(note.isFavorited ? .yellow : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .font(.subheadline).fontWeight(.medium).lineLimit(1)
                                        if !note.content.isEmpty {
                                            Text(note.content).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(16)
            .background(.clear)
            .premiumGlassCard()
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
                ModelMutationScheduler.shared.schedule { onDelete() }
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
