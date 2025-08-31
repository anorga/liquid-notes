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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
                    .opacity(themeManager.minimalMode ? 0.55 : 0.82)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tag \(tag)"))
    .scaleEffect(isPressed ? (themeManager.minimalMode ? 0.98 : 0.95) : 1.0)
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
            ).opacity(themeManager.glassOpacity * (themeManager.minimalMode ? 0.55 : 0.9))
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .modernGlassCard()
                        .onSubmit { addNewTag(onAdd: onAdd) }
                    Button(action: { addNewTag(onAdd: onAdd) }) {
                        Text("Add")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
        .padding(16)
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