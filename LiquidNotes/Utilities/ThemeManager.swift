import SwiftUI
import Combine

enum GlassTheme: String, CaseIterable {
    case clear = "Clear"
    case warm = "Warm"
    case cool = "Cool"
    case vibrant = "Vibrant"
    case midnight = "Midnight"
    case sunset = "Sunset"
    
    var primaryGradient: [Color] {
        switch self {
        case .clear:
            return [.white.opacity(0.1), .clear]
        case .warm:
            return [.orange.opacity(0.15), .pink.opacity(0.08)]
        case .cool:
            return [.blue.opacity(0.12), .cyan.opacity(0.06)]
        case .vibrant:
            return [.purple.opacity(0.15), .pink.opacity(0.1)]
        case .midnight:
            return [.indigo.opacity(0.2), .black.opacity(0.1)]
        case .sunset:
            return [.orange.opacity(0.18), .red.opacity(0.08)]
        }
    }
    
    var backgroundGradient: [Color] {
        switch self {
        case .clear:
            return [.clear, .gray.opacity(0.02)]
        case .warm:
            return [.orange.opacity(0.05), .yellow.opacity(0.03)]
        case .cool:
            return [.blue.opacity(0.04), .mint.opacity(0.02)]
        case .vibrant:
            return [.purple.opacity(0.06), .pink.opacity(0.04)]
        case .midnight:
            return [.indigo.opacity(0.08), .purple.opacity(0.04)]
        case .sunset:
            return [.orange.opacity(0.07), .red.opacity(0.03)]
        }
    }
    
    var glassOpacity: Double {
        switch self {
        case .clear: return 0.6
        case .warm: return 0.7
        case .cool: return 0.65
        case .vibrant: return 0.75
        case .midnight: return 0.8
        case .sunset: return 0.72
        }
    }
    
    var shadowIntensity: Double {
        switch self {
        case .clear: return 0.08
        case .warm: return 0.1
        case .cool: return 0.09
        case .vibrant: return 0.12
        case .midnight: return 0.15
        case .sunset: return 0.11
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: GlassTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    @Published var glassOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassOpacity, forKey: "glassOpacity")
        }
    }
    
    @Published var reduceMotion: Bool {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion")
        }
    }
    
    @Published var highContrast: Bool {
        didSet {
            UserDefaults.standard.set(highContrast, forKey: "highContrast")
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? GlassTheme.clear.rawValue
        self.currentTheme = GlassTheme(rawValue: savedTheme) ?? .clear
        self.glassOpacity = UserDefaults.standard.double(forKey: "glassOpacity")
        if self.glassOpacity == 0 {
            self.glassOpacity = 0.7
        }
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        self.highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    }
    
    func applyTheme(_ theme: GlassTheme) {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentTheme = theme
        }
    }
    
    func adjustOpacity(_ value: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            glassOpacity = max(0.3, min(0.95, value))
        }
    }
    
    func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentTheme = .clear
            glassOpacity = 0.7
            reduceMotion = false
            highContrast = false
        }
    }
}

struct ThemedGlassModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    let variant: GlassVariant
    let shape: AnyShape
    
    init<S: Shape>(variant: GlassVariant = .regular, shape: S) {
        self.variant = variant
        self.shape = AnyShape(shape)
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    shape.fill(.clear)
                    
                    shape.fill(
                        LinearGradient(
                            colors: themeManager.currentTheme.primaryGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(themeManager.glassOpacity)
                    )
                    
                    if themeManager.highContrast {
                        shape.stroke(
                            Color.primary.opacity(0.5),
                            lineWidth: 2
                        )
                    } else {
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    }
                }
            )
            .shadow(
                color: .black.opacity(themeManager.currentTheme.shadowIntensity),
                radius: themeManager.reduceMotion ? 4 : 8,
                x: 0,
                y: themeManager.reduceMotion ? 2 : 4
            )
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

extension View {
    func themedGlass<S: Shape>(_ variant: GlassVariant = .regular, in shape: S) -> some View {
        self.modifier(ThemedGlassModifier(variant: variant, shape: shape))
    }
    
    func themedGlassCard() -> some View {
        self.themedGlass(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}