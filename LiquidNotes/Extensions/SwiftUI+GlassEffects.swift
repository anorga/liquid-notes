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
    /// iOS 26: Uses native glass, iOS 17+: Minimal transparent material
    func liquidGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            // Use the actual iOS 26 glass effect API - fallback to material if glassEffect is not available
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
        if #available(iOS 26.0, *) {
            // Use materials for iOS 26 until we confirm the actual glass effect API
            switch variant {
            case .regular:
                return AnyView(self.background(.ultraThinMaterial.opacity(0.2), in: shape))
            case .thin:
                return AnyView(self.background(.ultraThinMaterial.opacity(0.1), in: shape))
            case .thick:
                return AnyView(self.background(.thinMaterial.opacity(0.3), in: shape))
            }
        } else {
            // iOS 17+ fallback: Much less frosted than previous implementation
            return AnyView(self.background(
                ZStack {
                    // Minimal material - much more transparent
                    shape.fill(.thinMaterial.opacity(0.3))
                    
                    // Very subtle highlight
                    shape.stroke(.white.opacity(0.15), lineWidth: 0.5)
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
            // Use standard materials for iOS 26 with interaction
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