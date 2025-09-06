import SwiftUI
import UIKit

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Solid black background per request
                Color.black.ignoresSafeArea()

                // Prefer asset named "AppSplashIcon"; fall back to bundled icon_source.png
                Group {
                    if let uiImage = UIImage(named: "AppSplashIcon") ?? UIImage(named: "icon_source") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        // Final fallback: simple logo text
                        Text("Liquid Notes")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: iconSize(for: geo), height: iconSize(for: geo))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        scale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.45)) {
                        opacity = 1.0
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
            let factor: CGFloat = (landscape && narrow) ? 0.22 : 0.28
            let cap: CGFloat = (landscape && narrow) ? 280 : 340
            return max(120, min(side * factor, cap))
        } else {
            return max(100, min(side * 0.38, 200))
        }
    }
}

#Preview {
    SplashView()
}
