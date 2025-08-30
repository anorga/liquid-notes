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
            return [.white.opacity(0.4), .gray.opacity(0.2)]
        case .warm:
            return [.orange.opacity(0.35), .pink.opacity(0.25)]
        case .cool:
            return [.blue.opacity(0.32), .cyan.opacity(0.22)]
        case .vibrant:
            return [.purple.opacity(0.38), .pink.opacity(0.28)]
        case .midnight:
            return [.indigo.opacity(0.45), .black.opacity(0.25)]
        case .sunset:
            return [.orange.opacity(0.42), .red.opacity(0.28)]
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
        case .vibrant:
            return [.purple.opacity(0.14), .pink.opacity(0.1)]
        case .midnight:
            return [.indigo.opacity(0.18), .purple.opacity(0.12)]
        case .sunset:
            return [.orange.opacity(0.16), .red.opacity(0.1)]
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
    
    @Published var animateGradients: Bool {
        didSet { UserDefaults.standard.set(animateGradients, forKey: "animateGradients") }
    }
    
    @Published var themeOverlayPinned: Bool {
        didSet { UserDefaults.standard.set(themeOverlayPinned, forKey: "themeOverlayPinned") }
    }
    
    @Published var dynamicTagCycling: Bool {
        didSet { UserDefaults.standard.set(dynamicTagCycling, forKey: "dynamicTagCycling") }
    }

    // New appearance options
    @Published var noteParallax: Bool {
        didSet { UserDefaults.standard.set(noteParallax, forKey: "noteParallax") }
    }
    @Published var noteGlassDepth: Double { // 0 = subtle, 1 = vivid
        didSet { UserDefaults.standard.set(noteGlassDepth, forKey: "noteGlassDepth") }
    }
    @Published var noteStyle: Int { // 0 = rounded, 1 = squircle
        didSet { UserDefaults.standard.set(noteStyle, forKey: "noteStyle") }
    }
    @Published var minimalMode: Bool { // flattens shadows, reduces blur
        didSet { UserDefaults.standard.set(minimalMode, forKey: "minimalMode") }
    }
    @Published var tagAccentSolid: Bool { // solid instead of gradient tags
        didSet { UserDefaults.standard.set(tagAccentSolid, forKey: "tagAccentSolid") }
    }
    @Published var showAdvancedGlass: Bool { // toggles advanced controls UI only
        didSet { UserDefaults.standard.set(showAdvancedGlass, forKey: "showAdvancedGlass") }
    }

    // Combined slider convenience (0.0 - 1.0). Setting it adjusts both glassOpacity and noteGlassDepth proportionally.
    var glassIntensity: Double {
        get {
            // normalize depth (noteGlassDepth default center 0.75) and opacity (0.3-0.95)
            let normOpacity = (glassOpacity - 0.3) / 0.65 // 0..1
            let normDepth = noteGlassDepth / 1.2 // 0..1 (depth slider upper bound earlier 1.2)
            return (normOpacity * 0.55 + normDepth * 0.45)
        }
        set {
            let clamped = max(0, min(1, newValue))
            // Map back: bias opacity slightly more for readability
            glassOpacity = 0.3 + (clamped * 0.65)
            noteGlassDepth = 0.3 + (clamped * 0.9) // keep within 0.3...1.2
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? GlassTheme.clear.rawValue
        self.currentTheme = GlassTheme(rawValue: savedTheme) ?? .clear
        
        let savedOpacity = UserDefaults.standard.double(forKey: "glassOpacity")
        self.glassOpacity = savedOpacity == 0 ? 0.85 : savedOpacity
        
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        self.highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    self.animateGradients = UserDefaults.standard.object(forKey: "animateGradients") as? Bool ?? true
    self.themeOverlayPinned = UserDefaults.standard.object(forKey: "themeOverlayPinned") as? Bool ?? false
    self.dynamicTagCycling = UserDefaults.standard.object(forKey: "dynamicTagCycling") as? Bool ?? true
    self.noteParallax = UserDefaults.standard.object(forKey: "noteParallax") as? Bool ?? true
    self.noteGlassDepth = UserDefaults.standard.object(forKey: "noteGlassDepth") as? Double ?? 0.75
    self.noteStyle = UserDefaults.standard.object(forKey: "noteStyle") as? Int ?? 0
    self.minimalMode = UserDefaults.standard.object(forKey: "minimalMode") as? Bool ?? false
    self.tagAccentSolid = UserDefaults.standard.object(forKey: "tagAccentSolid") as? Bool ?? false
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