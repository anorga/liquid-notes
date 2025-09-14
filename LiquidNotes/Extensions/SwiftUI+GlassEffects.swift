import SwiftUI
import UIKit

extension View {
    /// Uses iOS 26 native materials with subtle hairline strokes and light shadow.
    func nativeGlassSurface(cornerRadius: CGFloat = 16, opacity: Double = 1.0) -> some View {
        let theme = ThemeManager.shared
        let isMidnight = theme.currentTheme == .midnight
        let baseOpacity = min(1.0, max(0.0, (0.4 + theme.glassOpacity * 0.4))) * opacity

        return self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial.opacity(isMidnight ? min(0.92, baseOpacity + 0.1) : baseOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(isMidnight ? 0.22 : 0.16), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    func nativeGlassBarBackground() -> some View {
        let theme = ThemeManager.shared
        let isMidnight = theme.currentTheme == .midnight
        let opacity = isMidnight ? 0.92 : (0.44 + theme.glassOpacity * 0.36)
        return self.background(Rectangle().fill(.thinMaterial.opacity(opacity)))
    }

    func nativeGlassChip(opacity: Double = 1.0) -> some View {
        let theme = ThemeManager.shared
        return self
            .background(Capsule().fill(.thinMaterial.opacity((0.44 + theme.glassOpacity * 0.36) * opacity)))
            .overlay(Capsule().stroke(.white.opacity(theme.currentTheme == .midnight ? 0.22 : 0.16), lineWidth: 0.5))
    }

    func nativeGlassCircle(opacity: Double = 1.0) -> some View {
        let theme = ThemeManager.shared
        return self
            .background(Circle().fill(.thinMaterial.opacity((0.44 + theme.glassOpacity * 0.36) * opacity)))
            .overlay(Circle().stroke(.white.opacity(theme.currentTheme == .midnight ? 0.22 : 0.16), lineWidth: 0.5))
    }

}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func modernGlassCard() -> some View { self.nativeGlassSurface(cornerRadius: UI.Corner.m) }
    
    func premiumGlassCard() -> some View { self.nativeGlassSurface(cornerRadius: UI.Corner.l) }
    
    func ambientGlassEffect() -> some View { self.nativeGlassSurface(cornerRadius: UI.Corner.sPlus, opacity: 0.9) }
    
    func glassTabBar() -> some View {
        self.nativeGlassSurface(cornerRadius: 0)
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: -1)
    }
    
    func interactiveGlassButton() -> some View {
        self.nativeGlassChip()
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(0.98)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: false)
    }
}

// MARK: - Refined Clear Glass (modernized)
extension View {
    // Removed refinedClearGlass and subtleParallax (native style enforced)

    // Reusable subtle liquid border (hairline) for small components (chips, icons)
    func liquidBorderHairline(cornerRadius: CGFloat = 12) -> some View {
        let theme = ThemeManager.shared
        let combined = theme.noteGlassDepth * theme.glassOpacity
        let baseAlpha: Double = theme.highContrast ? 0.65 : 0.42
        let hairlineAlpha = baseAlpha + combined * (theme.highContrast ? 0.18 : 0.12)
        return overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(colors: [
                        .white.opacity(hairlineAlpha),
                        .white.opacity(0.02)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: theme.highContrast ? 1 : 0.6
                )
                .blendMode(.plusLighter)
                .opacity(0.85)
        )
    }
}
