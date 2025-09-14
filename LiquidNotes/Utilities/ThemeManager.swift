import SwiftUI
import Combine

enum GlassTheme: String, CaseIterable {
    case clear = "Clear"
    case midnight = "Midnight"
    static var allCases: [GlassTheme] { [.clear, .midnight] }
    
    var primaryGradient: [Color] {
        switch self {
        case .clear:
            return [.white.opacity(0.4), .gray.opacity(0.2)]
        case .midnight:
            return [.gray.opacity(0.25), .black.opacity(0.4)]
        }
    }
    
    var backgroundGradient: [Color] {
        switch self {
        case .clear:
            return [.gray.opacity(0.1), .gray.opacity(0.06)]
        case .midnight:
            return [.gray.opacity(0.08), .black.opacity(0.05)]
        }
    }
    
    var glassOpacity: Double {
        switch self {
        case .clear: return 0.6
        case .midnight: return 0.35
        }
    }
    
    var shadowIntensity: Double {
        switch self {
        case .clear: return 0.08
        case .midnight: return 0.06
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
    // Minimal mode removed; native visuals are always on
    // Solid tag accent option removed; always false (use gradients)
    @Published var tagAccentSolid: Bool = false
    @Published var showAdvancedGlass: Bool { // toggles advanced controls UI only
        didSet { UserDefaults.standard.set(showAdvancedGlass, forKey: "showAdvancedGlass") }
    }

    // Prefer Apple's native glass visual (iOS 26+) over custom layered glass.
    // When enabled, surfaces will use thinner material, lighter strokes, and reduced shadows.
    // Prefer native glass toggle removed; native visuals are enforced

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
        var savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? GlassTheme.midnight.rawValue
        // Migrate legacy names to supported themes
        if savedTheme == "Vibrant" { savedTheme = GlassTheme.clear.rawValue }
        if savedTheme == "Sunset" { savedTheme = GlassTheme.midnight.rawValue }
        if savedTheme == "Aurora" { savedTheme = GlassTheme.midnight.rawValue }
        self.currentTheme = GlassTheme(rawValue: savedTheme) ?? .midnight
        
        let savedOpacity = UserDefaults.standard.double(forKey: "glassOpacity")
        self.glassOpacity = savedOpacity == 0 ? 0.85 : savedOpacity
        
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        self.highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    self.animateGradients = true
    self.themeOverlayPinned = false
    self.dynamicTagCycling = true
    self.noteParallax = false
    self.noteGlassDepth = UserDefaults.standard.object(forKey: "noteGlassDepth") as? Double ?? 0.75
    // minimalMode deprecated
    self.tagAccentSolid = false
    self.showAdvancedGlass = UserDefaults.standard.object(forKey: "showAdvancedGlass") as? Bool ?? false
    // preferNativeGlass deprecated
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
            currentTheme = .midnight
            glassOpacity = 0.85
            reduceMotion = false
            highContrast = false
        }
    }
}

