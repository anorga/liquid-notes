import SwiftUI
import SwiftData

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    LNHeader(title: "More") { EmptyView() }
                    VStack(spacing: 14) {
                        MoreNavLink(icon: "gearshape.fill", color: .blue, title: "Settings") { SettingsView().navigationBarHidden(true) }
                    }
                    .padding(.horizontal, UI.Space.xl)
                    .padding(.top, 12)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationBarHidden(true)
        }
    }
}

private struct MoreNavLink<Destination: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder let destination: () -> Destination
    @State private var pressed = false
    var body: some View {
        NavigationLink(destination: destination().navigationBarHidden(true)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: UI.Corner.s).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, UI.Space.m)
            .modernGlassCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MoreView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}
