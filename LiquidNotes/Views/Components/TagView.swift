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
                    LinearGradient(
                        colors: themeManager.currentTheme.primaryGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(themeManager.glassOpacity * 0.9)
                )
                .overlay(
                    Capsule().stroke(
                        themeManager.highContrast ? Color.primary.opacity(0.7) : Color.white.opacity(0.25), lineWidth: 1
                    )
                )
        )
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

struct TagListView: View {
    @Binding var tags: [String]
    let availableColors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .mint, .indigo]
    let onAdd: ((String) -> Void)?
    let onRemove: ((String) -> Void)?
    
    @State private var isAddingTag = false
    @State private var newTagText = ""
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tags", systemImage: "tag.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if onAdd != nil {
                    Button(action: {
                        withAnimation(.bouncy(duration: 0.3)) {
                            isAddingTag.toggle()
                        }
                    }) {
                        Image(systemName: isAddingTag ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            
            if isAddingTag, let onAdd = onAdd {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("New tag...", text: $newTagText)
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.clear)
                            .modernGlassCard()
                            .onSubmit {
                                addNewTag(onAdd: onAdd)
                            }
                        
                        Button(action: { addNewTag(onAdd: onAdd) }) {
                            Text("Add")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [selectedColor, selectedColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .disabled(newTagText.isEmpty)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedColor == color ? Color.primary : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                    .onTapGesture {
                                        withAnimation(.bouncy(duration: 0.2)) {
                                            selectedColor = color
                                        }
                                        HapticManager.shared.buttonTapped()
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                            TagView(
                                tag: tag,
                                color: availableColors[index % availableColors.count],
                                onDelete: onRemove != nil ? {
                                    withAnimation(.bouncy(duration: 0.3)) {
                                        onRemove?(tag)
                                    }
                                } : nil
                            )
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
    
    private func addNewTag(onAdd: (String) -> Void) {
        guard !newTagText.isEmpty else { return }
        onAdd(newTagText)
        newTagText = ""
        withAnimation(.bouncy(duration: 0.3)) {
            isAddingTag = false
        }
        HapticManager.shared.buttonTapped()
    }
}

struct PriorityIndicator: View {
    let priority: NotePriority
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.iconName)
                .font(.caption)
            
            Text(priority.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            priority.color,
                            priority.color.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: priority.color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

struct DueDateBadge: View {
    let date: Date
    
    private var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }
    
    private var badgeColor: Color {
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue == 0 {
            return .orange
        } else if daysUntilDue <= 3 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var badgeText: String {
        if daysUntilDue < 0 {
            return "Overdue"
        } else if daysUntilDue == 0 {
            return "Today"
        } else if daysUntilDue == 1 {
            return "Tomorrow"
        } else if daysUntilDue <= 7 {
            return "\(daysUntilDue) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
            
            Text(badgeText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            badgeColor,
                            badgeColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: badgeColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}