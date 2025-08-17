//
//  LiquidGlassView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI

struct LiquidGlassView<Content: View>: View {
    let theme: GlassTheme
    let motionData: MotionManager.MotionData
    let content: () -> Content
    
    init(theme: GlassTheme, motionData: MotionManager.MotionData, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.motionData = motionData
        self.content = content
    }
    
    var body: some View {
        content()
            .background(
                GlassBackground(theme: theme, motionData: motionData)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: .black.opacity(0.1),
                radius: 8,
                x: glassOffset.width * 0.5,
                y: glassOffset.height * 0.5
            )
            .offset(glassOffset)
    }
    
    private var glassOffset: CGSize {
        guard theme.motionResponseIntensity > 0 else { return .zero }
        
        let maxOffset: Double = 3.0
        let intensity = theme.motionResponseIntensity
        
        let offsetX = sin(motionData.roll) * maxOffset * intensity
        let offsetY = sin(motionData.pitch) * maxOffset * intensity
        
        return CGSize(width: offsetX, height: offsetY)
    }
}

struct GlassBackground: View {
    let theme: GlassTheme
    let motionData: MotionManager.MotionData
    
    var body: some View {
        ZStack {
            // Base glass material
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(theme.baseOpacity)
                .background(theme.tintColor)
                .blur(radius: theme.blurRadius * 0.1)
            
            // Specular highlight
            if theme.reflectionEnabled {
                SpecularHighlightView(
                    theme: theme,
                    motionData: motionData
                )
            }
            
            // Additional blur overlay for frosted effect
            Rectangle()
                .fill(.white.opacity(0.05))
                .blur(radius: theme.blurRadius * 0.2)
        }
    }
}

struct SpecularHighlightView: View {
    let theme: GlassTheme
    let motionData: MotionManager.MotionData
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(highlightOpacity),
                        .clear,
                        .white.opacity(highlightOpacity * 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(theme.highlightIntensity)
            .offset(highlightOffset)
            .blur(radius: 2)
    }
    
    private var highlightOpacity: Double {
        let baseOpacity = 0.3
        let motionFactor = abs(sin(motionData.pitch)) + abs(sin(motionData.roll))
        return min(1.0, baseOpacity + motionFactor * 0.2)
    }
    
    private var highlightOffset: CGSize {
        let maxOffset: Double = 15.0
        let intensity = theme.motionResponseIntensity
        
        let offsetX = -sin(motionData.roll) * maxOffset * intensity
        let offsetY = -sin(motionData.pitch) * maxOffset * intensity
        
        return CGSize(width: offsetX, height: offsetY)
    }
}

#Preview {
    LiquidGlassView(
        theme: GlassTheme.defaultThemes[0],
        motionData: MotionManager.MotionData()
    ) {
        VStack(spacing: 12) {
            Text("Sample Note")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This is a sample note with liquid glass effects.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    .padding()
    .background(.gray.opacity(0.1))
}