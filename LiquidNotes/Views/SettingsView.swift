import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetConfirmation = false
    @AppStorage("showArchivedInPlace") private var showArchivedInPlace = false
    @AppStorage("enableSwipeAffordance") private var enableSwipeAffordance = true
    @AppStorage("enableArchiveUndo") private var enableArchiveUndo = true
    @ObservedObject private var motion = MotionManager.shared
    @AppStorage("dailyReviewReminderEnabled") private var dailyReviewReminderEnabled = false
    @AppStorage("dailyReviewReminderHour") private var dailyReviewReminderHour = 9
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        LNHeader(title: "Settings") { EmptyView() }

                        VStack(spacing: 24) {
                            themeSection
                            canvasSection
                            archiveSection
                            productivitySection
                            analyticsSection
                            aboutSection
                        }
                        .padding(.horizontal, UI.Space.xl)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
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

    private var depthLabel: String {
        switch themeManager.noteGlassDepth {
        case ..<0.45: return "Subtle"
        case ..<0.75: return "Balanced"
        case ..<1.0: return "Rich"
        default: return "Vivid"
        }
    }

    private var intensityLabel: String {
        let v = themeManager.glassIntensity
        switch v {
        case ..<0.25: return "Airy"
        case ..<0.55: return "Balanced"
        case ..<0.8: return "Lush"
        default: return "Vivid"
        }
    }

    private var archiveSection: some View {
        EmptyView()
    }

    @AppStorage("spatialMagneticClustering") private var magneticClustering = false

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Canvas", systemImage: "rectangle.on.rectangle.angled")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                SettingToggle(
                    title: "Magnetic Clustering",
                    description: "Notes snap to align with nearby notes",
                    icon: "magnet",
                    isOn: $magneticClustering
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
                
                // Follow system appearance is always on. Only show themes valid
                // for the current color scheme: Light in light mode; Midnight/Night in dark.
                let allowedThemes: [GlassTheme] = (colorScheme == .dark) ? [.midnight, .night] : [.light]
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(allowedThemes, id: \.self) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            themeManager.applyTheme(theme)
                            HapticManager.shared.buttonTapped()
                        }
                    }
                }
                .opacity(1.0)
                .allowsHitTesting(true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Glass Intensity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(intensityLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tertiary.opacity(0.2), in: Capsule())
                }
                Slider(value: Binding(
                    get: { themeManager.glassIntensity },
                    set: { newVal in themeManager.glassIntensity = newVal; HapticManager.shared.buttonTapped() }
                ), in: 0...1) {
                    Text("Glass Intensity")
                }
                .tint(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))

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

            Divider().padding(.vertical, 8)

            SettingToggle(
                title: "Motion Parallax",
                description: "Cards shift subtly with device tilt",
                icon: "gyroscope",
                isOn: Binding(
                    get: { themeManager.noteParallax },
                    set: { newVal in
                        themeManager.noteParallax = newVal
                        if newVal && themeManager.isMotionAllowed {
                            MotionManager.shared.startTracking()
                        } else {
                            MotionManager.shared.stopTracking()
                        }
                    }
                )
            )

            if themeManager.noteParallax && UIAccessibility.isReduceMotionEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Reduce Motion is enabled in system settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 48)
            }
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }
    
    // accessibilitySection removed for production
    
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

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Productivity", systemImage: "bolt.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            VStack(spacing: 0) {
                SettingToggle(
                    title: "Daily Review Reminder",
                    description: "Prompt to review notes each day",
                    icon: "bell.badge",
                    isOn: $dailyReviewReminderEnabled
                )
                .onChange(of: dailyReviewReminderEnabled) { _, newVal in
                    if newVal { NotificationScheduler.scheduleDailyReview(hour: dailyReviewReminderHour) } else { NotificationScheduler.cancelDailyReview() }
                }
                Divider().padding(.leading, 8)
                HStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminder Time")
                            .font(.callout)
                            .fontWeight(.medium)
                        Text("Hour of day (24h)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper(value: $dailyReviewReminderHour, in: 5...22, step: 1) {
                        Text("\(dailyReviewReminderHour):00")
                            .font(.callout)
                            .monospacedDigit()
                    }
                    .onChange(of: dailyReviewReminderHour) { _, _ in
                        if dailyReviewReminderEnabled { NotificationScheduler.scheduleDailyReview(hour: dailyReviewReminderHour) }
                    }
                }
                .padding(.vertical, UI.Space.m)
            }
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Usage Analytics", systemImage: "chart.bar.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            let a = AnalyticsManager.shared
            VStack(alignment: .leading, spacing: 10) {
                analyticsRow("Daily Review Opens", a.value("cmd.dailyReview"))
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(.clear)
        .premiumGlassCard()
    }

    
}

private func analyticsRow(_ title: String, _ val: Int) -> some View {
    HStack {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text("\(val)").font(.caption).fontWeight(.semibold)
    }
}

struct ThemeButton: View {
    let theme: GlassTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: UI.Corner.s)
                    .fill(
                        LinearGradient(
                            colors: previewColors(),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: UI.Corner.s)
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

    private func previewColors() -> [Color] {
        switch theme {
        case .light:
            // Keep light neutral
            return [Color.white.opacity(0.85), Color.white.opacity(0.65)]
        case .night:
            // Subtle cool undertones to match previews
            return [Color.blue.opacity(0.28), Color.cyan.opacity(0.24)]
        case .midnight:
            // Black-ish appearance
            return [Color.black.opacity(0.6), Color.black.opacity(0.35)]
        }
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
        .padding(.vertical, UI.Space.m)
    }
}

#Preview {
    SettingsView()
}
