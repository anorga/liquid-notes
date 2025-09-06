import SwiftUI
import Combine

enum GlassTheme: String, CaseIterable {
    case clear = "Clear"
    case warm = "Warm"
    case cool = "Cool"
    case neon = "Neon"
    case midnight = "Midnight"
    case aurora = "Aurora"
    
    var primaryGradient: [Color] {
        switch self {
        case .clear:
            return [.white.opacity(0.4), .gray.opacity(0.2)]
        case .warm:
            return [.orange.opacity(0.35), .pink.opacity(0.25)]
        case .cool:
            return [.blue.opacity(0.32), .cyan.opacity(0.22)]
        case .neon:
            // Bright, energetic green → cyan
            return [.green.opacity(0.40), .cyan.opacity(0.30)]
        case .midnight:
            return [.indigo.opacity(0.45), .black.opacity(0.25)]
        case .aurora:
            // Calm, premium mint → teal
            return [.mint.opacity(0.34), .teal.opacity(0.28)]
        }
    }
    
    var backgroundGradient: [Color] {
        switch self {
        case .clear:
            return [.gray.opacity(0.1), .gray.opacity(0.06)]
        case .warm:
            return [.orange.opacity(0.12), .yellow.opacity(0.08)]
        case .cool:
            return [.blue.opacity(0.1), .mint.opacity(0.06)]
        case .neon:
            return [.green.opacity(0.16), .cyan.opacity(0.12)]
        case .midnight:
            return [.indigo.opacity(0.18), .purple.opacity(0.12)]
        case .aurora:
            return [.mint.opacity(0.14), .teal.opacity(0.10)]
        }
    }
    
    var glassOpacity: Double {
        switch self {
        case .clear: return 0.6
        case .warm: return 0.7
        case .cool: return 0.65
        case .neon: return 0.76
        case .midnight: return 0.8
        case .aurora: return 0.70
        }
    }
    
    var shadowIntensity: Double {
        switch self {
        case .clear: return 0.08
        case .warm: return 0.1
        case .cool: return 0.09
        case .neon: return 0.12
        case .midnight: return 0.15
        case .aurora: return 0.10
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
    
    // Removed user-facing toggles; keep constants
    @Published var animateGradients: Bool = true
    @Published var themeOverlayPinned: Bool = false
    @Published var dynamicTagCycling: Bool = true

    // New appearance options
    // Parallax always off per simplification
    @Published var noteParallax: Bool = false
    @Published var noteGlassDepth: Double { // 0 = subtle, 1 = vivid
        didSet { UserDefaults.standard.set(noteGlassDepth, forKey: "noteGlassDepth") }
    }
    @Published var minimalMode: Bool { // flattens shadows, reduces blur
        didSet { UserDefaults.standard.set(minimalMode, forKey: "minimalMode") }
    }
    // Solid tag accent option removed; always false (use gradients)
    @Published var tagAccentSolid: Bool = false
    @Published var showAdvancedGlass: Bool { // toggles advanced controls UI only
        didSet { UserDefaults.standard.set(showAdvancedGlass, forKey: "showAdvancedGlass") }
    }

    // Combined slider convenience (0.0 - 1.0). Setting it adjusts both glassOpacity and noteGlassDepth proportionally.
    var glassIntensity: Double {
        get {
            // Simplified: treat intensity as direct opacity curve favoring clarity at low end
            // Map glassOpacity (0.3...0.95) to 0...1 with slight easing
            let t = (glassOpacity - 0.3) / 0.65
            return max(0, min(1, t))
        }
        set {
            let clamped = max(0, min(1, newValue))
            // Ease-in for opacity so early slider movement stays clearer (more transparent)
            let eased = pow(clamped, 1.2)
            glassOpacity = 0.3 + eased * 0.65
            // Derive depth more subtly so it increases slower for clearer subtle end
            noteGlassDepth = 0.3 + eased * 0.6
        }
    }
    
    private init() {
        var savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? GlassTheme.clear.rawValue
        // Migrate legacy names to new ones
        if savedTheme == "Vibrant" { savedTheme = GlassTheme.neon.rawValue }
        if savedTheme == "Sunset" { savedTheme = GlassTheme.aurora.rawValue }
        self.currentTheme = GlassTheme(rawValue: savedTheme) ?? .clear
        
        let savedOpacity = UserDefaults.standard.double(forKey: "glassOpacity")
        self.glassOpacity = savedOpacity == 0 ? 0.85 : savedOpacity
        
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        self.highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    self.animateGradients = true
    self.themeOverlayPinned = false
    self.dynamicTagCycling = true
    self.noteParallax = false
    self.noteGlassDepth = UserDefaults.standard.object(forKey: "noteGlassDepth") as? Double ?? 0.75
    self.minimalMode = UserDefaults.standard.object(forKey: "minimalMode") as? Bool ?? false
    self.tagAccentSolid = false
    self.showAdvancedGlass = UserDefaults.standard.object(forKey: "showAdvancedGlass") as? Bool ?? false
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
            glassOpacity = 0.85
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
    private let makePath: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        makePath = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        makePath(rect)
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
