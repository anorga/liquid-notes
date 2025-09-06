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
                    Group {
                        if let uiImage = UIImage(named: "AppSplashIcon") ?? UIImage(named: "icon_source") {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            // Final fallback: simple logo text
                            Text("Liquidnote")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

                    // App name under the icon with subtle shimmer
                    ZStack {
                        // Base title
                        Text("Liquidnote")
                            .font(.system(size: titleSize(for: geo), weight: .semibold, design: .rounded))
                            .kerning(0.6)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                        // Shimmer overlay masked by the same text
                        Text("Liquidnote")
                            .font(.system(size: titleSize(for: geo), weight: .semibold, design: .rounded))
                            .kerning(0.6)
                            .foregroundStyle(.clear)
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.0),
                                        .white.opacity(0.25),
                                        .white.opacity(0.9),
                                        .white.opacity(0.25),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: max(140, min(geo.size.width * 0.5, 320)), height: titleSize(for: geo) * 1.6)
                                .rotationEffect(.degrees(18))
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
                    // Icon bounce + fade
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { scale = 1.06 }
                    withAnimation(.easeOut(duration: 0.45)) { opacity = 1.0 }
                    // Settle from slight overshoot
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9).delay(0.15)) { scale = 1.0 }
                    // Title slide/fade
                    withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                        titleOpacity = 1.0
                        titleOffset = 0
                    }
                    // Shimmer sweep across the title
                    shimmerX = -geo.size.width
                    withAnimation(.linear(duration: 1.35).delay(0.35).repeatForever(autoreverses: false)) {
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
            // Make icon larger overall on iPad, still considerate of split view
            let factor: CGFloat = (landscape && narrow) ? 0.28 : 0.36
            let cap: CGFloat = (landscape && narrow) ? 340 : 400
            return max(140, min(side * factor, cap))
        } else {
            // Make icon larger on iPhone as well
            return max(120, min(side * 0.48, 240))
        }
    }

    private func titleSize(for geo: GeometryProxy) -> CGFloat {
        let side = min(geo.size.width, geo.size.height)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return isPad ? min(28, side * 0.05) : min(24, side * 0.07)
    }
}

#Preview {
    SplashView()
}
