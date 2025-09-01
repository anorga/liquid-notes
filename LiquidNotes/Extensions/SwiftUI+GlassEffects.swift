import SwiftUI
import UIKit

extension View {
    func liquidGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.background(.ultraThinMaterial.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)))
        } else {
            return AnyView(self.background(.thinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 12)))
        }
    }
    
    func liquidGlassCard() -> some View {
        self.liquidGlassBackground()
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
    
    func liquidGlassEffect<S: Shape>(_ variant: GlassVariant = .regular, in shape: S) -> some View {
        let theme = ThemeManager.shared
        // if #available(iOS 26.0, *) {
            switch variant {
            case .regular:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(Color.clear)
                        
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.6)
                        )
                        if theme.highContrast {
                            shape.stroke(Color.primary.opacity(0.6), lineWidth: 2)
                        } else {
                            shape.stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.35),
                                        .white.opacity(0.08),
                                        .black.opacity(0.12)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                        }
                    }
                ))
            case .thin:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(Color.clear)
                        shape.stroke(theme.highContrast ? Color.primary.opacity(0.5) : .primary.opacity(0.15), lineWidth: theme.highContrast ? 1 : 0.5)
                    }
                ))
            case .thick:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.55)
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.45),
                                    .white.opacity(0.15),
                                    .black.opacity(0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                    }
                ))
            case .ultra:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.4)
                        )
                        shape.stroke(theme.highContrast ? Color.primary.opacity(0.7) : .white.opacity(0.25), lineWidth: theme.highContrast ? 1.2 : 0.8)
                    }
                ))
            case .floating:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.7)
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                    }
                ))
            case .elevated:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.75)
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.55),
                                    .white.opacity(0.25),
                                    .black.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    }
                ))
            case .ambient:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.backgroundGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity * 0.5)
                        )
                        shape.stroke(theme.highContrast ? Color.primary.opacity(0.6) : .white.opacity(0.2), lineWidth: 0.8)
                    }
                ))
            case .vibrant:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: theme.currentTheme.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(theme.glassOpacity)
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.45),
                                    .blue.opacity(0.12),
                                    .purple.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                    }
                ))
            }
        // } else {
        //     // iOS 17+: Apple-style glass borders with system adaptation
        //     return AnyView(self.background(
        //         ZStack {
        //             shape.fill(
        //                 LinearGradient(
        //                     colors: theme.currentTheme.primaryGradient,
        //                     startPoint: .topLeading,
        //                     endPoint: .bottomTrailing
        //                 ).opacity(theme.glassOpacity * 0.65)
        //             )
        //             if theme.highContrast {
        //                 shape.stroke(Color.primary.opacity(0.55), lineWidth: 1.2)
        //             } else {
        //                 shape.stroke(
        //                     LinearGradient(
        //                         colors: [
        //                             .primary.opacity(0.18),
        //                             .primary.opacity(0.05),
        //                             .secondary.opacity(0.1)
        //                         ],
        //                         startPoint: .topLeading,
        //                         endPoint: .bottomTrailing
        //                     ),
        //                     lineWidth: 0.8
        //                 )
        //             }
        //         }
        //     ))
        // }
    }
    
    /// Convenience overload for common shapes  
    func liquidGlassEffect(_ variant: GlassVariant = .regular) -> some View {
        self.liquidGlassEffect(variant, in: Capsule())
    }
    
    /// Interactive glass effect with touch response
    func interactiveGlassEffect<S: Shape>(_ variant: GlassVariant = .regular, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            // Use enhanced materials for iOS 26 with spatial interaction
            return AnyView(self.liquidGlassEffect(variant, in: shape)
                .scaleEffect(0.98)
                .animation(.easeInOut(duration: 0.15), value: false))
        } else {
            // iOS 17+ fallback with enhanced interaction
            return AnyView(self.liquidGlassEffect(variant, in: shape)
                .scaleEffect(0.98)
                .animation(.easeInOut(duration: 0.15), value: false))
        }
    }
}

// MARK: - Glass Effect Types

enum GlassVariant {
    case regular
    case thin
    case thick
    case ultra
    case floating
    case elevated
    case ambient
    case vibrant
    
    func tint(_ color: Color) -> TintedGlassVariant {
        TintedGlassVariant(base: self, tint: color)
    }
    
    func interactive() -> InteractiveGlassVariant {
        InteractiveGlassVariant(base: self)
    }
}

struct TintedGlassVariant {
    let base: GlassVariant
    let tint: Color
    
    func interactive() -> InteractiveTintedGlassVariant {
        InteractiveTintedGlassVariant(base: base, tint: tint)
    }
}

struct InteractiveGlassVariant {
    let base: GlassVariant
}

struct InteractiveTintedGlassVariant {
    let base: GlassVariant  
    let tint: Color
}

struct GlassDepthLayer {
    let opacity: Double
    let blur: CGFloat
    let offset: CGSize
    let tint: Color
    
    static let subtle = GlassDepthLayer(opacity: 0.05, blur: 1, offset: CGSize(width: 0, height: 0.5), tint: .white)
    static let medium = GlassDepthLayer(opacity: 0.1, blur: 2, offset: CGSize(width: 0, height: 1), tint: .white)
    static let pronounced = GlassDepthLayer(opacity: 0.15, blur: 4, offset: CGSize(width: 0, height: 2), tint: .white)
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
    
    func modernGlassCard() -> some View {
        self.liquidGlassEffect(.floating, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    func premiumGlassCard() -> some View {
        self.liquidGlassEffect(.elevated, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
    }
    
    func ambientGlassEffect() -> some View {
        self.liquidGlassEffect(.ambient, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .blue.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    func glassTabBar() -> some View {
        self.liquidGlassEffect(.ultra, in: RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: -1)
    }
    
    func interactiveGlassButton() -> some View {
        self.liquidGlassEffect(.vibrant, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(0.98)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: false)
    }
}

// MARK: - Refined Clear Glass (modernized)
extension View {
    func refinedClearGlass(cornerRadius: CGFloat = 22, intensity: Double = 1.0) -> some View {
        let theme = ThemeManager.shared
    // Blend noteGlassDepth (passed as intensity) with global glassOpacity; adapt for minimalMode
    let depth = intensity
    let opacityFactor = theme.glassOpacity // 0.3 ... 0.95
    let combined = depth * opacityFactor // master factor
    // Base translucency target: lower values = more transparent
    let materialOpacity = 0.25 + combined * 0.55 // 0.25 ... ~0.8
    // Gradient strength (color wash)
    let gradientAlpha = 0.08 + combined * 0.28 + (theme.highContrast ? 0.08 : 0)
    let gradientColors = theme.currentTheme.primaryGradient.map { $0.opacity(gradientAlpha) }
    // Stroke & glow scaling (re-tuned for subtle "liquid" border)
    // We collapse dual-stroke system into a single adaptive hairline + faint inner highlight
    let hairlineAlpha = (theme.highContrast ? 0.75 : 0.45) + combined * (theme.highContrast ? 0.15 : 0.10)
    let innerHighlightAlpha = (theme.highContrast ? 0.35 : 0.20) + combined * 0.08
    let outerShadowAlpha = 0.18 + combined * 0.18 + (theme.highContrast ? 0.06 : 0)
    let haloAlpha = 0.05 + combined * 0.12 + (theme.highContrast ? 0.08 : 0)
    let minimal = theme.minimalMode
    let blurRadius = minimal ? 4 : (theme.reduceMotion ? 8 : 18 + combined * 14)
    let gradientBlur = minimal ? 6 : (theme.reduceMotion ? 10 : 24 + combined * 10)
        return self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial.opacity(materialOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            .blur(radius: gradientBlur)
            .opacity(0.85)
            )
            // Unified liquid border system: subtle hairline + inner luminous edge
            .overlay(
                ZStack {
                    // Hairline (outer) – very subtle, adaptive
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [
                                .white.opacity(hairlineAlpha),
                                .white.opacity(0.02)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: theme.highContrast ? 1.1 : 0.7
                        )
                        .blendMode(.plusLighter)
                        .opacity(minimal ? 0.55 : 0.85)
                    // Inner highlight (simulated inner shadow inverse)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [
                                (theme.currentTheme.primaryGradient.first ?? .white).opacity(innerHighlightAlpha * 0.9),
                                .clear
                            ], startPoint: .bottomTrailing, endPoint: .topLeading),
                            lineWidth: theme.highContrast ? 0.9 : 0.6
                        )
                        .blur(radius: 1.0)
                        .opacity(minimal ? 0.35 : 0.55)
                        .blendMode(.screen)
                }
            )
            .shadow(color: .black.opacity(minimal ? outerShadowAlpha * 0.4 : outerShadowAlpha), radius: (minimal ? 8 : 16) + combined * (minimal ? 2 : 6), x: 0, y: minimal ? 6 : 10)
            .shadow(color: (theme.currentTheme.primaryGradient.first ?? .white).opacity(minimal ? haloAlpha * 0.5 : haloAlpha), radius: (minimal ? 16 : 30) + combined * (minimal ? 8 : 18), x: 0, y: minimal ? 12 : 20)
        .blur(radius: blurRadius * 0.0) // placeholder if future depth-of-field needed
    }
    
    func subtleParallax(_ motion: MotionManager = .shared, maxOffset: CGFloat = 8) -> some View {
        let values = motion.normalizedMotionValues()
        return self.offset(x: values.x * maxOffset, y: values.y * maxOffset)
    }

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
                .opacity(theme.minimalMode ? 0.55 : 0.85)
        )
    }
}