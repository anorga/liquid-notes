import SwiftUI

struct LiquidNotesBackground: View {
    @State private var animationProgress: Double = 0
    @Environment(\.colorScheme) var colorScheme
    
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
            Color(colorScheme == .dark ? .black : .systemGray6)
                .ignoresSafeArea()
            
            ZStack {
                EllipticalGradient(
                    colors: ambientColors,
                    center: UnitPoint(x: 0.3 + animationProgress * 0.1, y: 0.2 + animationProgress * 0.1),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                )
                .opacity(0.6)
                .blur(radius: 60)
                
                EllipticalGradient(
                    colors: ambientColors.reversed(),
                    center: UnitPoint(x: 0.7 - animationProgress * 0.1, y: 0.8 - animationProgress * 0.1),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .opacity(0.4)
                .blur(radius: 80)
                
                LinearGradient(
                    colors: [
                        ambientColors.first?.opacity(0.02) ?? .clear,
                        .clear,
                        ambientColors.last?.opacity(0.03) ?? .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.8)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 20)
                    .repeatForever(autoreverses: true)
                ) {
                    animationProgress = 1.0
                }
            }
            
            if colorScheme == .dark {
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 400
                        )
                    )
                    .ignoresSafeArea()
            }
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