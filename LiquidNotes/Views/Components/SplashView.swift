import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            // Use the same aesthetic as the app — glassy gradient background
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ModernAppIcon()
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                VStack(spacing: 6) {
                    Text("Liquid Notes")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(0.95)
                    Text("Think fluidly. Capture clearly.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 0.35)) {
                    opacity = 1.0
                }
            }
        }
    }
}

#Preview {
    SplashView()
}

