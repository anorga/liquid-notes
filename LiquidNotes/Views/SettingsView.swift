import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
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
                            archiveSection
                            accessibilitySection
                            productivitySection
                            analyticsSection
                            aboutSection
                        }
                        .padding(.horizontal, 20)
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
    // Simplified per feedback: removed inline archive visibility / swipe / undo options
    EmptyView()
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
                Divider().padding(.vertical, 4)
                SettingToggle(
                    title: "Minimal Mode",
                    description: "Flatter surfaces & lighter shadows",
                    icon: "rectangle.compress.vertical",
                    isOn: $themeManager.minimalMode
                )
                SettingToggle(
                    title: "(Background Animation Always On)",
                    description: "",
                    icon: "sparkles",
                    isOn: .constant(true)
                ).hidden()
                Divider().padding(.vertical, 6)
                // Note Style picker removed; unified style applied globally
                // Advanced glass controls removed for simplification
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
                .onChange(of: themeManager.reduceMotion) { _, newValue in
                    MotionManager.shared.syncWithReduceMotion(newValue)
                }
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
                .padding(.vertical, 12)
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