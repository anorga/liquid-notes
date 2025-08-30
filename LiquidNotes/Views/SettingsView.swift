import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showResetConfirmation = false
    @AppStorage("showArchivedInPlace") private var showArchivedInPlace = false
    @AppStorage("enableSwipeAffordance") private var enableSwipeAffordance = true
    @AppStorage("enableArchiveUndo") private var enableArchiveUndo = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        themeSection
                        archiveSection
                        accessibilitySection
                        aboutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                themeManager.resetToDefaults()
                HapticManager.shared.success()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notes Behavior", systemImage: "archivebox")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            VStack(spacing: 0) {
                SettingToggle(
                    title: "Show Archived Inline",
                    description: "Display archived notes faded at the end",
                    icon: "eye",
                    isOn: $showArchivedInPlace
                )
                Divider().padding(.horizontal)
                SettingToggle(
                    title: "Swipe Hints",
                    description: "Show subtle arrows on horizontal swipe",
                    icon: "arrow.left.and.right",
                    isOn: $enableSwipeAffordance
                )
                Divider().padding(.horizontal)
                SettingToggle(
                    title: "Archive Undo",
                    description: "Offer undo after archiving",
                    icon: "clock.arrow.circlepath",
                    isOn: $enableArchiveUndo
                )
            }
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintbrush.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Glass Theme")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(GlassTheme.allCases, id: \.self) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            themeManager.applyTheme(theme)
                            HapticManager.shared.buttonTapped()
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Glass Opacity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(themeManager.glassOpacity * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tertiary.opacity(0.2), in: Capsule())
                }
                
                Slider(
                    value: $themeManager.glassOpacity,
                    in: 0.3...0.95,
                    step: 0.05
                ) {
                    Text("Glass Opacity")
                } onEditingChanged: { editing in
                    if !editing {
                        HapticManager.shared.buttonTapped()
                    }
                }
                .tint(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                HStack {
                    Text("Subtle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Opaque")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }
    
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Accessibility", systemImage: "accessibility")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(spacing: 0) {
                SettingToggle(
                    title: "High Contrast",
                    description: "Increase contrast for better visibility",
                    icon: "circle.lefthalf.filled",
                    isOn: $themeManager.highContrast
                )
                
                Divider()
                    .padding(.horizontal)
                
                SettingToggle(
                    title: "Reduce Motion",
                    description: "Minimize animations and transitions",
                    icon: "figure.walk.motion",
                    isOn: $themeManager.reduceMotion
                )
            }
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("About", systemImage: "info.circle.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1.0.0")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                Button(action: {
                    showResetConfirmation = true
                    HapticManager.shared.buttonTapped()
                }) {
                    HStack {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(.clear)
        .ambientGlassEffect()
    }
}

struct ThemeButton: View {
    let theme: GlassTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: theme.primaryGradient.map { $0.opacity(1.0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .shadow(
                        color: .black.opacity(theme.shadowIntensity),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                
                Text(theme.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.bouncy(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct SettingToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: isOn ? [.green, .mint] : [Color.gray, Color.gray.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _, _ in
                    HapticManager.shared.buttonTapped()
                }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    SettingsView()
}