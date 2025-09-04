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
                    .padding(.horizontal, 20)
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
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
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.clear)
                    .refinedClearGlass(cornerRadius: 22, intensity: ThemeManager.shared.noteGlassDepth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.17), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(ThemeManager.shared.minimalMode ? 0.04 : 0.14), radius: ThemeManager.shared.minimalMode ? 4 : 10, x: 0, y: ThemeManager.shared.minimalMode ? 2 : 5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MoreView()
        .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}
