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
    /// Apply system material background for Liquid Glass effect
    /// Apple's guidance: "Leverage system frameworks to adopt Liquid Glass automatically"
    func liquidGlassBackground() -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    /// Apply liquid glass card style using system materials
    func liquidGlassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}