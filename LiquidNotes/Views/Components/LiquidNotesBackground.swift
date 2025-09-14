import SwiftUI

struct LiquidNotesBackground: View {
    @State private var animationProgress: Double = 0
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    private var ambientColors: [Color] {
        switch currentHour {
        case 5..<8:
            return [.orange.opacity(0.1), .pink.opacity(0.08), .yellow.opacity(0.05)]
        case 8..<11:
            return [.blue.opacity(0.08), .cyan.opacity(0.06), .mint.opacity(0.04)]
        case 11..<14:
            return [.cyan.opacity(0.06), .blue.opacity(0.04), .indigo.opacity(0.03)]
        case 14..<17:
            return [.green.opacity(0.07), .teal.opacity(0.05), .cyan.opacity(0.04)]
        case 17..<20:
            return [.orange.opacity(0.09), .red.opacity(0.06), .pink.opacity(0.04)]
        case 20..<23:
            return [.purple.opacity(0.08), .indigo.opacity(0.06), .blue.opacity(0.04)]
        default:
            return [.indigo.opacity(0.06), .purple.opacity(0.04), .blue.opacity(0.03)]
        }
    }
    
    var body: some View {
        ZStack {
            // Brand base: fused theme gradient + adaptive neutral
            let theme = themeManager.currentTheme
            let isMidnight = theme == .midnight
            let baseNeutral = isMidnight ? Color.black : Color(colorScheme == .dark ? .black : .white)
            
            if isMidnight {
                Color.black
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        (theme.primaryGradient.first ?? .blue).opacity(colorScheme == .dark ? 0.18 : 0.22),
                        (theme.primaryGradient.last ?? .purple).opacity(colorScheme == .dark ? 0.14 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    baseNeutral.opacity(colorScheme == .dark ? 0.55 : 0.75)
                )
                .blendMode(.plusLighter)
                .ignoresSafeArea()
            }
            
            ZStack {
                EllipticalGradient(
                    colors: ambientColors,
                    center: UnitPoint(x: 0.3 + animationProgress * 0.1, y: 0.2 + animationProgress * 0.1),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                )
                .opacity(isMidnight ? 0.1 : 0.6)
                .blur(radius: 60)
                
                EllipticalGradient(
                    colors: ambientColors.reversed(),
                    center: UnitPoint(x: 0.7 - animationProgress * 0.1, y: 0.8 - animationProgress * 0.1),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .opacity(isMidnight ? 0.08 : 0.4)
                .blur(radius: 80)
                
                // Brand accent veil using theme gradient
                LinearGradient(
                    colors: [
                        (theme.primaryGradient.first ?? .clear).opacity(0.04 + themeManager.glassOpacity * 0.05),
                        .clear,
                        (theme.primaryGradient.last ?? .clear).opacity(0.06 + themeManager.glassOpacity * 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.9)
                .blendMode(.screen)
                .allowsHitTesting(false)

                // Subtle noise / texture overlay (procedural via blending tiny gradient grid)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.015 : 0.03),
                                .white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.overlay)
                    .opacity(0.5)
            }
            .ignoresSafeArea()
            .onAppear {
                if themeManager.animateGradients {
                    withAnimation(
                        .easeInOut(duration: 20)
                        .repeatForever(autoreverses: true)
                    ) { animationProgress = 1.0 }
                }
            }
            .onChange(of: themeManager.animateGradients) { _, newValue in
                if newValue {
                    animationProgress = 0
                    withAnimation(
                        .easeInOut(duration: 20)
                        .repeatForever(autoreverses: true)
                    ) { animationProgress = 1.0 }
                } else {
                    withAnimation(.easeOut(duration: 0.6)) { animationProgress = 0 }
                }
            }
            
            // Unified vignette (slightly stronger in dark)
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            (colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.08))
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 500
                    )
                )
                .blendMode(.multiply)
                .ignoresSafeArea()
        }
    }
}

struct DepthBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var offset3: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .systemGray6)
                .ignoresSafeArea()
            
            Circle()
                .fill(.blue.opacity(colorScheme == .dark ? 0.03 : 0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(offset1)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 25)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset1 = CGSize(width: 100, height: -50)
                    }
                }
            
            Circle()
                .fill(.purple.opacity(colorScheme == .dark ? 0.02 : 0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(offset2)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 30)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset2 = CGSize(width: -80, height: 100)
                    }
                }
            
            Circle()
                .fill(.cyan.opacity(colorScheme == .dark ? 0.02 : 0.03))
                .frame(width: 250, height: 250)
                .blur(radius: 90)
                .offset(offset3)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 35)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset3 = CGSize(width: 60, height: 80)
                    }
                }
        }
    }
}

#Preview {
    LiquidNotesBackground()
}

#Preview("Depth Background") {
    DepthBackground()
}
