import SwiftUI
import UIKit

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0
    @State private var titleOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 10
    @State private var shimmerX: CGFloat = -300

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Solid black background per request
                Color.black.ignoresSafeArea()

                // Prefer asset named "AppSplashIcon"; fall back to bundled icon_source.png
                VStack(spacing: 18) {
                    if let uiImage = UIImage(named: "AppSplashIcon") ?? UIImage(named: "icon_source") {
                        ZStack {
                            Color.black
                                .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                            
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: iconSize(for: geo) + 10, height: iconSize(for: geo) + 10)
                                .offset(y: -8) // Shift image up significantly to hide bottom
                                .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: iconSize(for: geo) * 0.2237, style: .continuous))
                            // Hard-mask any residual single-pixel edge from the source asset
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 3)
                                .frame(width: iconSize(for: geo))
                                .alignmentGuide(.bottom) { d in d[.bottom] }
                                .offset(y: (iconSize(for: geo)/2) - 1.5)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: iconSize(for: geo) * 0.2237, style: .continuous))
                        }
                        .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                    } else {
                        // Final fallback: simple logo text
                        Text("Liquidnote")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                    }

                    // App name under the icon with subtle shimmer
                    ZStack {
                        // Base title
                        Text("Liquidnote")
                            .font(.system(size: titleSize(for: geo), weight: .semibold, design: .rounded))
                            .kerning(0.6)
                            .foregroundStyle(.white)

                        // Shimmer overlay masked by the same text - MORE DRAMATIC
                        Text("Liquidnote")
                            .font(.system(size: titleSize(for: geo), weight: .semibold, design: .rounded))
                            .kerning(0.6)
                            .foregroundStyle(.clear)
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.0),
                                        .white.opacity(0.3),
                                        .white.opacity(1.0),
                                        .white.opacity(0.3),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 120)
                                .offset(x: shimmerX)
                                .blendMode(.screen)
                            )
                            .mask(
                                Text("Liquidnote")
                                    .font(.system(size: titleSize(for: geo), weight: .semibold, design: .rounded))
                                    .kerning(0.6)
                            )
                    }
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    // More dramatic icon bounce + fade
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) { scale = 1.15 }
                    withAnimation(.easeOut(duration: 0.35)) { opacity = 1.0 }
                    // Settle from larger overshoot
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) { scale = 1.0 }
                    // Title slide/fade with more drama
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.25)) {
                        titleOpacity = 1.0
                        titleOffset = 0
                    }
                    // Faster, more frequent shimmer sweep
                    shimmerX = -geo.size.width
                    withAnimation(.linear(duration: 0.9).delay(0.4).repeatForever(autoreverses: false)) {
                        shimmerX = geo.size.width
                    }
                }
            }
        }
    }

    private func iconSize(for geo: GeometryProxy) -> CGFloat {
        let w = geo.size.width
        let h = geo.size.height
        let side = min(w, h)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if isPad {
            let landscape = w > h
            let narrow = w < 800 // split view or compact window
            // Increased by ~33% from previous values
            let factor: CGFloat = (landscape && narrow) ? 0.37 : 0.48
            let cap: CGFloat = (landscape && narrow) ? 450 : 530
            return max(185, min(side * factor, cap))
        } else {
            // Increased by ~33% for iPhone
            return max(160, min(side * 0.64, 320))
        }
    }

    private func titleSize(for geo: GeometryProxy) -> CGFloat {
        let side = min(geo.size.width, geo.size.height)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        // Increased text size by ~40%
        return isPad ? min(40, side * 0.07) : min(34, side * 0.10)
    }
}

#Preview {
    SplashView()
}
