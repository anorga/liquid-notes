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
        
        switch variant {
        case .regular:
            if theme.reduceMotion || theme.minimalMode {
                return AnyView(self.background(
                    shape.fill(.ultraThinMaterial.opacity(theme.glassOpacity * 0.8))
                ))
            } else {
                return AnyView(self.background(
                    ZStack {
                        shape.fill(.ultraThinMaterial.opacity(theme.glassOpacity * 0.4))
                        
                        if !theme.highContrast {
                            shape.stroke(.white.opacity(0.2), lineWidth: 0.5)
                        }
                    }
                ))
            }
        case .thin:
            return AnyView(self.background(
                shape.fill(.thinMaterial.opacity(theme.glassOpacity * 0.6))
            ))
        case .thick:
            return AnyView(self.background(
                ZStack {
                    shape.fill(.regularMaterial.opacity(theme.glassOpacity * 0.7))
                    if !theme.minimalMode {
                        shape.stroke(.white.opacity(0.15), lineWidth: 0.8)
                    }
                }
            ))
        case .ultra:
            return AnyView(self.background(
                ZStack {
                    shape.fill(.ultraThinMaterial.opacity(theme.glassOpacity * 0.5))
                    if !theme.minimalMode {
                        shape.stroke(.white.opacity(0.25), lineWidth: 0.8)
                    }
                }
            ))
        case .floating:
            return AnyView(self.background(
                shape.fill(.thickMaterial.opacity(theme.glassOpacity * 0.8))
            ))
        case .elevated:
            return AnyView(self.background(
                shape.fill(.regularMaterial.opacity(theme.glassOpacity * 0.9))
            ))
        case .ambient:
            return AnyView(self.background(
                shape.fill(.ultraThinMaterial.opacity(theme.glassOpacity * 0.4))
            ))
        case .vibrant:
            return AnyView(self.background(
                ZStack {
                    shape.fill(.thickMaterial.opacity(theme.glassOpacity))
                    if !theme.minimalMode {
                        shape.stroke(.white.opacity(0.3), lineWidth: 0.5)
                    }
                }
            ))
        }
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
        let materialOpacity = 0.4 + (intensity * theme.glassOpacity * 0.4)
        
        return Group {
            if theme.minimalMode || theme.reduceMotion {
                self
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(materialOpacity))
                    )
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            } else {
                self
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(materialOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
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