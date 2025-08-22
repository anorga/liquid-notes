//
//  ModernAppIcon.swift
//  LiquidNotes
//
//  Created for iOS 26 modern design
//

import SwiftUI

// MARK: - iOS 26 Modern App Icon with Y2K Aesthetic

struct ModernAppIcon: View {
    var body: some View {
        ZStack {
            // Base container with iOS standard corner radius
            RoundedRectangle(cornerRadius: 45)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.sRGB, red: 0.02, green: 0.02, blue: 0.08, opacity: 1.0),
                            Color(.sRGB, red: 0.08, green: 0.08, blue: 0.12, opacity: 1.0),
                            Color(.sRGB, red: 0.01, green: 0.01, blue: 0.04, opacity: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
            
            // 3D Layered Notes Stack
            ZStack {
                // Bottom note - largest, darkest shadow
                noteLayer(
                    width: 140,
                    height: 100,
                    rotation: -8,
                    offset: CGSize(width: 15, height: 20),
                    gradient: bottomNoteGradient,
                    shadowOpacity: 0.4,
                    shadowRadius: 8
                )
                
                // Middle note - medium shadow
                noteLayer(
                    width: 130,
                    height: 95,
                    rotation: 2,
                    offset: CGSize(width: -5, height: 5),
                    gradient: middleNoteGradient,
                    shadowOpacity: 0.3,
                    shadowRadius: 6
                )
                
                // Top note - lightest, with blue accent
                noteLayer(
                    width: 120,
                    height: 90,
                    rotation: -3,
                    offset: CGSize(width: 8, height: -10),
                    gradient: topNoteGradient,
                    shadowOpacity: 0.2,
                    shadowRadius: 4,
                    hasAccent: true
                )
            }
        }
    }
    
    // MARK: - Individual Note Layer
    
    private func noteLayer(
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        offset: CGSize,
        gradient: LinearGradient,
        shadowOpacity: Double,
        shadowRadius: CGFloat,
        hasAccent: Bool = false
    ) -> some View {
        ZStack {
            // Main note body
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient)
                .frame(width: width, height: height)
                .overlay(
                    // Inner highlight for 3D effect
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    // Y2K-style blue accent edge (top note only)
                    Group {
                        if hasAccent {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(.sRGB, red: 0.3, green: 0.6, blue: 1.0, opacity: 0.8),
                                            Color(.sRGB, red: 0.1, green: 0.3, blue: 0.7, opacity: 0.4)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    }
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 3,
                    y: 6
                )
            
            // Subtle horizontal lines for note paper effect
            VStack(spacing: height * 0.15) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: width * 0.7, height: 1)
                }
            }
            .offset(y: height * 0.1)
        }
        .rotationEffect(.degrees(rotation))
        .offset(offset)
    }
    
    // MARK: - Gradient Definitions
    
    private var bottomNoteGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.sRGB, red: 0.18, green: 0.18, blue: 0.22, opacity: 1.0),
                Color(.sRGB, red: 0.12, green: 0.12, blue: 0.16, opacity: 1.0),
                Color(.sRGB, red: 0.08, green: 0.08, blue: 0.12, opacity: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var middleNoteGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.sRGB, red: 0.25, green: 0.25, blue: 0.30, opacity: 1.0),
                Color(.sRGB, red: 0.18, green: 0.18, blue: 0.23, opacity: 1.0),
                Color(.sRGB, red: 0.12, green: 0.12, blue: 0.18, opacity: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var topNoteGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.sRGB, red: 0.35, green: 0.35, blue: 0.40, opacity: 1.0),
                Color(.sRGB, red: 0.25, green: 0.25, blue: 0.32, opacity: 1.0),
                Color(.sRGB, red: 0.18, green: 0.18, blue: 0.25, opacity: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ModernAppIcon()
        .background(Color.black)
}