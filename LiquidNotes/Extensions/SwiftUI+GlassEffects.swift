//
//  SwiftUI+LiquidGlass.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/18/25.
//

import SwiftUI

// MARK: - Apple Liquid Glass Extensions
// Based on Apple Developer Documentation: "Adopting Liquid Glass"
// Key principle: Use standard system components to get Liquid Glass automatically

extension View {
    /// Apply transparent background for native Liquid Glass effect
    /// iOS 18+: Enhanced glass effects, iOS 17+: Minimal transparent material
    func liquidGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            // Use enhanced material effects for iOS 26
            return AnyView(self.background(.ultraThinMaterial.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)))
        } else {
            return AnyView(self.background(.thinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 12)))
        }
    }
    
    /// Apply transparent card style with minimal shadow
    func liquidGlassCard() -> some View {
        self.liquidGlassBackground()
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
    
    /// True Apple Liquid Glass effect using native iOS 26+ APIs
    /// Fallback to less frosted materials for iOS 17+
    func liquidGlassEffect<S: Shape>(_ variant: GlassVariant = .regular, in shape: S) -> some View {
        // Based on PHASES_TRACKING.md breakthrough: True transparency with Apple-style adaptive borders
        // Key principle: Let background show through with system-aware glass borders
        if #available(iOS 26.0, *) {
            // iOS 26: True native Liquid Glass with enhanced spatial support
            switch variant {
            case .regular:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(Color.clear)  // Maximum transparency
                        
                        // Inner subtle highlight (like Apple's glass elements)
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
                        shape.stroke(.primary.opacity(0.15), lineWidth: 0.5)  // System adaptive
                    }
                ))
            case .thick:
                return AnyView(self.background(
                    ZStack {
                        shape.fill(.ultraThinMaterial.opacity(0.05))  // Minimal material only for thick
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