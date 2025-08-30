import SwiftUI

extension Color {
    func hueShift(_ degrees: Double) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let newHue = (Double(h) + degrees / 360.0).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: newHue < 0 ? newHue + 1 : newHue, saturation: Double(s), brightness: Double(b), opacity: Double(a))
        #else
        return self // macOS Catalyst fallback
        #endif
    }
}