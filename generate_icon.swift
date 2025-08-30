#!/usr/bin/env swift

import Foundation
import UIKit
import SwiftUI

struct IconGenerator {
    static func createModernIcon() -> UIImage? {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            let backgroundColors = [
                UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1.0).cgColor
            ]
            
            let backgroundGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                              colors: backgroundColors as CFArray,
                                              locations: [0.0, 0.5, 1.0])!
            
            let cornerRadius: CGFloat = 45
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            ctx.addPath(path.cgPath)
            ctx.clip()
            
            ctx.drawLinearGradient(backgroundGradient,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: size.width, y: size.height),
                                 options: [])
            
            drawNote(in: ctx, size: size, layer: 0)
            drawNote(in: ctx, size: size, layer: 1)
            drawNote(in: ctx, size: size, layer: 2)
        }
    }
    
    private static func drawNote(in ctx: CGContext, size: CGSize, layer: Int) {
        ctx.saveGState()
        
        let noteConfigs = [
            (width: 140.0, height: 100.0, rotation: -8.0, offsetX: 15.0, offsetY: 20.0,
             colors: [UIColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1.0).cgColor,
                     UIColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0).cgColor,
                     UIColor(red: 0.35, green: 0.35, blue: 0.45, alpha: 1.0).cgColor]),
            (width: 130.0, height: 95.0, rotation: 2.0, offsetX: -5.0, offsetY: 5.0,
             colors: [UIColor(red: 0.65, green: 0.65, blue: 0.75, alpha: 1.0).cgColor,
                     UIColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1.0).cgColor,
                     UIColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0).cgColor]),
            (width: 120.0, height: 90.0, rotation: -3.0, offsetX: 8.0, offsetY: -10.0,
             colors: [UIColor(red: 0.80, green: 0.80, blue: 0.88, alpha: 1.0).cgColor,
                     UIColor(red: 0.70, green: 0.70, blue: 0.78, alpha: 1.0).cgColor,
                     UIColor(red: 0.60, green: 0.60, blue: 0.68, alpha: 1.0).cgColor])
        ]
        
        let config = noteConfigs[layer]
        
        let scale = size.width / 200
        let noteWidth = config.width * scale
        let noteHeight = config.height * scale
        let centerX = size.width / 2 + config.offsetX * scale
        let centerY = size.height / 2 + config.offsetY * scale
        
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: config.rotation * .pi / 180)
        
        let shadowOffset = CGSize(width: 3 * scale, height: 6 * scale)
        let shadowOpacity: [CGFloat] = [0.4, 0.3, 0.2]
        let shadowRadius: CGFloat = [8, 6, 4][layer] * scale
        
        ctx.setShadow(offset: shadowOffset, blur: shadowRadius, 
                     color: UIColor.black.withAlphaComponent(shadowOpacity[layer]).cgColor)
        
        let noteRect = CGRect(x: -noteWidth/2, y: -noteHeight/2, width: noteWidth, height: noteHeight)
        let notePath = UIBezierPath(roundedRect: noteRect, cornerRadius: 8 * scale)
        
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: config.colors as CFArray,
                                locations: [0.0, 0.5, 1.0])!
        
        ctx.addPath(notePath.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                             start: CGPoint(x: -noteWidth/2, y: -noteHeight/2),
                             end: CGPoint(x: noteWidth/2, y: noteHeight/2),
                             options: [])
        
        ctx.resetClip()
        
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(2.5 * scale)
        ctx.addPath(notePath.cgPath)
        ctx.strokePath()
        
        if layer == 2 {
            ctx.setStrokeColor(UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.9).cgColor)
            ctx.setLineWidth(3 * scale)
            ctx.addPath(notePath.cgPath)
            ctx.strokePath()
            
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            ctx.setLineWidth(1.5 * scale)
            ctx.addPath(notePath.cgPath)
            ctx.strokePath()
        } else {
            ctx.setStrokeColor(UIColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 0.4).cgColor)
            ctx.setLineWidth(1.5 * scale)
            ctx.addPath(notePath.cgPath)
            ctx.strokePath()
        }
        
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1.5 * scale)
        
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

if let iconImage = IconGenerator.createModernIcon() {
    if let pngData = iconImage.pngData() {
        let currentDir = FileManager.default.currentDirectoryPath
        let iconPath = "\(currentDir)/LiquidNotes/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
        
        do {
            try pngData.write(to: URL(fileURLWithPath: iconPath))
            print("✅ New modern app icon generated successfully!")
        } catch {
            print("❌ Failed to save icon: \(error)")
        }
    }
} else {
    print("❌ Failed to generate icon")
}