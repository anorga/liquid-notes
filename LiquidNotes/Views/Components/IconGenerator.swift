import SwiftUI
import UIKit

struct IconGenerator {
    static func createModernIcon() -> UIImage? {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Background with dark Y2K gradient
            let backgroundColors = [
                UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1.0).cgColor
            ]
            
            let backgroundGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                              colors: backgroundColors as CFArray,
                                              locations: [0.0, 0.5, 1.0])!
            
            // Create rounded rectangle path
            let cornerRadius: CGFloat = 45
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            ctx.addPath(path.cgPath)
            ctx.clip()
            
            // Draw background gradient
            ctx.drawLinearGradient(backgroundGradient,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: size.width, y: size.height),
                                 options: [])
            
            // Draw three layered notes
            drawNote(in: ctx, size: size, layer: 0) // Bottom note
            drawNote(in: ctx, size: size, layer: 1) // Middle note  
            drawNote(in: ctx, size: size, layer: 2) // Top note
        }
    }
    
    private static func drawNote(in ctx: CGContext, size: CGSize, layer: Int) {
        ctx.saveGState()
        
        // Note properties based on layer
        let noteConfigs = [
            // Bottom note
            (width: 140.0, height: 100.0, rotation: -8.0, offsetX: 15.0, offsetY: 20.0,
             colors: [UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0).cgColor,
                     UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0).cgColor,
                     UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor]),
            // Middle note
            (width: 130.0, height: 95.0, rotation: 2.0, offsetX: -5.0, offsetY: 5.0,
             colors: [UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0).cgColor,
                     UIColor(red: 0.18, green: 0.18, blue: 0.23, alpha: 1.0).cgColor,
                     UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0).cgColor]),
            // Top note
            (width: 120.0, height: 90.0, rotation: -3.0, offsetX: 8.0, offsetY: -10.0,
             colors: [UIColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1.0).cgColor,
                     UIColor(red: 0.25, green: 0.25, blue: 0.32, alpha: 1.0).cgColor,
                     UIColor(red: 0.18, green: 0.18, blue: 0.25, alpha: 1.0).cgColor])
        ]
        
        let config = noteConfigs[layer]
        
        // Scale to 1024x1024 canvas
        let scale = size.width / 200
        let noteWidth = config.width * scale
        let noteHeight = config.height * scale
        let centerX = size.width / 2 + config.offsetX * scale
        let centerY = size.height / 2 + config.offsetY * scale
        
        // Apply rotation
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: config.rotation * .pi / 180)
        
        // Draw shadow
        let shadowOffset = CGSize(width: 3 * scale, height: 6 * scale)
        let shadowOpacity: [CGFloat] = [0.4, 0.3, 0.2]
        let shadowRadius: CGFloat = [8, 6, 4][layer] * scale
        
        ctx.setShadow(offset: shadowOffset, blur: shadowRadius, 
                     color: UIColor.black.withAlphaComponent(shadowOpacity[layer]).cgColor)
        
        // Create note rectangle
        let noteRect = CGRect(x: -noteWidth/2, y: -noteHeight/2, width: noteWidth, height: noteHeight)
        let notePath = UIBezierPath(roundedRect: noteRect, cornerRadius: 8 * scale)
        
        // Fill with gradient
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: config.colors as CFArray,
                                locations: [0.0, 0.5, 1.0])!
        
        ctx.addPath(notePath.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                             start: CGPoint(x: -noteWidth/2, y: -noteHeight/2),
                             end: CGPoint(x: noteWidth/2, y: noteHeight/2),
                             options: [])
        
        // Reset clipping for next elements
        ctx.resetClip()
        
        // Draw highlight border
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1 * scale)
        ctx.addPath(notePath.cgPath)
        ctx.strokePath()
        
        // Draw blue accent for top note
        if layer == 2 {
            ctx.setStrokeColor(UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8).cgColor)
            ctx.setLineWidth(1.5 * scale)
            ctx.addPath(notePath.cgPath)
            ctx.strokePath()
        }
        
        // Draw paper lines
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        ctx.setLineWidth(1)
        
        let lineSpacing = noteHeight * 0.15
        let lineWidth = noteWidth * 0.7
        let startY = -noteHeight/2 + noteHeight * 0.25
        
        for i in 0..<3 {
            let y = startY + CGFloat(i) * lineSpacing
            ctx.move(to: CGPoint(x: -lineWidth/2, y: y))
            ctx.addLine(to: CGPoint(x: lineWidth/2, y: y))
            ctx.strokePath()
        }
        
        ctx.restoreGState()
    }
}