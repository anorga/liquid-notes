import SwiftUI

struct FloatingActionButton: View {
    enum Action: Hashable { case newNote, quickTask, newFolder, dailyReview, commands, reindex }
    let available: [Action]
    let perform: (Action) -> Void
    @State private var expanded = false
    @State private var rotation: CGFloat = 0
    @Namespace private var anim
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: toggle) {
                Image(systemName: expanded ? "xmark" : "square.and.pencil")
                    .font(.title2.weight(.semibold))
                    .padding(18)
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .animation(.spring(response:0.45,dampingFraction:0.75), value: expanded)
            }
            .accessibilityLabel(expanded ? "Close actions" : "Create or command")
            .interactiveGlassButton()
            if expanded {
                VStack(spacing: 8) {
                    ForEach(available, id: \.self) { act in
                        Button(action: { trigger(act) }) { label(for: act) }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    .padding(.trailing, 16)
    .padding(.top, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(.spring(response:0.5,dampingFraction:0.82), value: expanded)
    }
    private func toggle() { withAnimation { expanded.toggle() } }
    private func trigger(_ a: Action) { HapticManager.shared.buttonTapped(); perform(a); if a != .commands { withAnimation { expanded = false } } }
    @ViewBuilder private func label(for action: Action) -> some View {
        let (icon, text, tint): (String,String,Color) = {
            switch action {
            case .newNote: return ("doc.badge.plus","New Note", .accentColor)
            case .quickTask: return ("checklist","Quick Task", .green)
            case .newFolder: return ("folder.badge.plus","New Folder", .orange)
            case .dailyReview: return ("calendar","Daily Review", .pink)
            case .commands: return ("command","Commands", .purple)
            case .reindex: return ("arrow.triangle.2.circlepath","Reindex", .teal)
            }
        }()
        HStack(spacing: 10) {
            Text(text).font(.caption).fontWeight(.medium).foregroundStyle(.primary)
                .padding(.vertical, 8).padding(.leading, 12).padding(.trailing, 10)
                .background(
                    Capsule().fill(LinearGradient(colors:[tint.opacity(0.28), tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(
                    Capsule().stroke(tint.opacity(0.35), lineWidth: 0.6)
                )
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(10)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    FloatingActionButton(available: [.newNote,.quickTask,.newFolder,.commands]) { _ in }
}