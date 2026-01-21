import SwiftUI

struct TagView: View {
    let tag: String
    let color: Color
    let onDelete: (() -> Void)?
    
    @State private var isPressed = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(tag: String, color: Color = .blue, onDelete: (() -> Void)? = nil) {
        self.tag = tag
        self.color = color
        self.onDelete = onDelete
    }
    
    var body: some View {
    HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, UI.Space.m)
        .padding(.vertical, UI.Space.xs)
        .background(
            Capsule()
                .fill(
                    tagFill()
                )
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [
                            .white.opacity(themeManager.highContrast ? 0.7 : 0.45 + themeManager.glassOpacity * 0.15),
                            .white.opacity(0.02)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: themeManager.highContrast ? 0.9 : 0.6
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.82)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tag \(tag)"))
    .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.bouncy(duration: 0.2)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.bouncy(duration: 0.2)) {
                    isPressed = false
                }
            }
        }
    }
}

private extension TagView {
    func animatedGradient() -> [Color] {
        let base = themeManager.currentTheme.primaryGradient
        let time = Date().timeIntervalSince1970
        let phase = sin(time.truncatingRemainder(dividingBy: 8) / 8 * .pi * 2)
        return base.enumerated().map { idx, color in
            let shift = (phase * 25) + Double(idx) * 18
            return color.hueShift(shift)
        }
    }

    func tagFill() -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: animatedGradient(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).opacity(themeManager.glassOpacity * 0.9)
        )
    }
}

struct TagListView: View {
    @Binding var tags: [String]
    // Color selection removed; always uses animated gradient
    let onAdd: ((String) -> Void)?
    let onRemove: ((String) -> Void)?
    
    @State private var isAddingTag = false
    @State private var newTagText = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tags", systemImage: "tag.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                if onAdd != nil {
                    Button(action: { withAnimation(.bouncy(duration: 0.3)) { isAddingTag.toggle() } }) {
                        Image(systemName: isAddingTag ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
            }
            if isAddingTag, let onAdd = onAdd {
                HStack(spacing: 12) {
                    TextField("New tag...", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    .padding(.horizontal, UI.Space.l)
                    .padding(.vertical, UI.Space.m)
                        .background(.clear)
                        .modernGlassCard()
                        .onSubmit { addNewTag(onAdd: onAdd) }
                    Button(action: { addNewTag(onAdd: onAdd) }) {
                        Text("Add")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    .padding(.horizontal, UI.Space.l)
                    .padding(.vertical, UI.Space.m)
                            .background(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Capsule())
                    }
                    .disabled(newTagText.isEmpty)
                    .opacity(newTagText.isEmpty ? 0.4 : 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Use stable identity by the string itself
                        ForEach(tags, id: \.self) { tag in
                            TagView(tag: tag, color: .blue, onDelete: onRemove != nil ? { withAnimation(.bouncy(duration: 0.3)) { onRemove?(tag) } } : nil)
                        }
                    }
                }
            } else {
                Text("No tags yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(UI.Space.l)
        .background(.clear)
        .premiumGlassCard()
    }
}

private extension TagListView {
    func addNewTag(onAdd: (String) -> Void) {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(trimmed) {
            onAdd(trimmed)
            newTagText = ""
        }
    }
}

struct SuggestedTagsView: View {
    let note: Note
    @State private var isAnalyzing = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        if !note.suggestedTags.isEmpty || isAnalyzing {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Suggested Tags")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if !note.suggestedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(zip(note.suggestedTags.indices, note.suggestedTags)), id: \.0) { index, tag in
                                SuggestedTagChip(
                                    tag: tag,
                                    confidence: index < note.tagConfidences.count ? note.tagConfidences[index] : 0.8,
                                    onAccept: {
                                        HapticManager.shared.success()
                                        ModelMutationScheduler.shared.schedule {
                                            note.acceptSuggestedTag(tag)
                                        }
                                    },
                                    onDismiss: {
                                        HapticManager.shared.buttonTapped()
                                        ModelMutationScheduler.shared.schedule {
                                            note.dismissSuggestedTag(tag)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(UI.Space.m)
            .nativeGlassSurface(cornerRadius: UI.Corner.m)
        }
    }

    func analyzeNote() {
        guard note.suggestedTags.isEmpty else { return }
        isAnalyzing = true
        NoteIntelligenceService.shared.analyzeNote(note) { tags, confidences in
            ModelMutationScheduler.shared.schedule {
                note.suggestedTags = tags.filter { !note.tags.contains($0) }
                note.tagConfidences = confidences
                note.lastAnalyzedDate = Date()
            }
            isAnalyzing = false
        }
    }
}

struct SuggestedTagChip: View {
    let tag: String
    let confidence: Double
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var isPressed = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Button(action: onAccept) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, UI.Space.m)
        .padding(.vertical, UI.Space.xs)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [
                            .white.opacity(0.45 + themeManager.glassOpacity * 0.15),
                            .white.opacity(0.02)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.6
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.82)
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.bouncy(duration: 0.2), value: isPressed)
    }
}

struct RelatedNotesView: View {
    let note: Note
    let allNotes: [Note]
    let onNoteTap: (Note) -> Void

    @State private var relatedNotes: [Note] = []
    @State private var isLoading = false

    var body: some View {
        if !relatedNotes.isEmpty || isLoading {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Related Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if !relatedNotes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(relatedNotes, id: \.id) { relatedNote in
                            Button {
                                HapticManager.shared.noteSelected()
                                onNoteTap(relatedNote)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relatedNote.title.isEmpty ? "Untitled" : relatedNote.title)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if !relatedNote.content.isEmpty {
                                            Text(relatedNote.content)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .nativeGlassSurface(cornerRadius: UI.Corner.s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(UI.Space.m)
            .nativeGlassSurface(cornerRadius: UI.Corner.m)
        }
    }

    func findRelatedNotes() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let similar = NoteIntelligenceService.shared.suggestLinkedNotes(for: note, from: allNotes)
            DispatchQueue.main.async {
                relatedNotes = similar
                isLoading = false
            }
        }
    }
}
