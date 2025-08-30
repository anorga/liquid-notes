import SwiftUI

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
        if #available(iOS 26.0, *) {
            switch variant {
            case .regular:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(Color.clear)
                        
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.08),     // Top inner highlight
                                    .clear,                    // Middle transparent
                                    .clear                     // Bottom transparent
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        
                        // Apple-style adaptive border that changes with light/dark mode
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),      // Top highlight
                                    .white.opacity(0.1),      // Middle
                                    .black.opacity(0.1)       // Bottom shadow
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                    }
                ))
            case .thin:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(Color.clear)
                        shape.stroke(.primary.opacity(0.15), lineWidth: 0.5)
                    }
                ))
            case .thick:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(.ultraThinMaterial.opacity(0.05))
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1),
                                    .black.opacity(0.15)
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
                        shape.fill(.clear)
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    .clear,
                                    .black.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        shape.stroke(.white.opacity(0.25), lineWidth: 0.8)
                    }
                ))
            case .floating:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(.ultraThinMaterial.opacity(0.08))
                        shape.fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.35),
                                    .white.opacity(0.05)
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
                        shape.fill(.regularMaterial.opacity(0.1))
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.15),
                                    .white.opacity(0.02),
                                    .black.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.2),
                                    .black.opacity(0.1)
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
                        shape.fill(.thinMaterial.opacity(0.12))
                        shape.fill(
                            AngularGradient(
                                colors: [
                                    .blue.opacity(0.03),
                                    .purple.opacity(0.02),
                                    .pink.opacity(0.03),
                                    .blue.opacity(0.03)
                                ],
                                center: .center
                            )
                        )
                        shape.stroke(.white.opacity(0.2), lineWidth: 0.8)
                    }
                ))
            case .vibrant:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(.ultraThinMaterial.opacity(0.15))
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .blue.opacity(0.02),
                                    .purple.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .blue.opacity(0.1),
                                    .purple.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                    }
                ))
            }
        } else {
            // iOS 17+: Apple-style glass borders with system adaptation
            return AnyView(self.background(
                ZStack {
                    shape.fill(Color.clear)  // Pure transparency
                    
                    // Inner highlight for depth (adapts to light/dark mode)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                .primary.opacity(0.06),    // Top highlight (adapts to theme)
                                .clear,                     // Middle transparent
                                .clear                      // Bottom transparent
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    
                    // Multi-layer border system like Apple's tab bar glass
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                .primary.opacity(0.2),     // Adapts to light/dark mode
                                .primary.opacity(0.05),    // Middle
                                .secondary.opacity(0.1)    // Bottom definition
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
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

extension View {
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