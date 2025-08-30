#!/usr/bin/env swift

import Foundation
import CoreGraphics
import AppKit

struct IconGenerator {
    static func createModernIcon() -> CGImage? {
        let width = 1024
        let height = 1024
        let size = CGSize(width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }

        let rect = CGRect(origin: .zero, size: size)

        // Background gradient (opaque)
        let backgroundColors: [CGColor] = [
            CGColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0),
            CGColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0),
            CGColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)
        ]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: backgroundColors as CFArray, locations: [0,0.55,1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: size.width, y: size.height),
                                   options: [])
        } else {
            ctx.setFillColor(backgroundColors[0])
            ctx.fill(rect)
        }

        // Inner highlight (still opaque)
        let innerInset: CGFloat = 24
        let innerRect = rect.insetBy(dx: innerInset, dy: innerInset)
        let innerPath = CGPath(roundedRect: innerRect, cornerWidth: 180, cornerHeight: 180, transform: nil)
        ctx.saveGState()
        ctx.addPath(innerPath)
        ctx.clip()
        if let innerGradient = CGGradient(colorsSpace: colorSpace,
                                          colors: [
                                            CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
                                            CGColor(red: 1, green: 1, blue: 1, alpha: 0.02)
                                          ] as CFArray,
                                          locations: [0,1]) {
            ctx.drawLinearGradient(innerGradient,
                                   start: CGPoint(x: rect.midX, y: rect.minY),
                                   end: CGPoint(x: rect.midX, y: rect.maxY),
                                   options: [])
        }
        ctx.restoreGState()

        // Notes stack
        for layer in 0..<3 { drawNote(in: ctx, size: size, layer: layer) }

        return ctx.makeImage()
    }

    private static func drawNote(in ctx: CGContext, size: CGSize, layer: Int) {
        ctx.saveGState()
        let noteConfigs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, [CGColor])] = [
            (140,100,-8, 15, 20, [
                CGColor(gray: 0.60, alpha: 1.0),
                CGColor(gray: 0.52, alpha: 1.0),
                CGColor(gray: 0.42, alpha: 1.0)
            ]),
            (130,95, 2, -5, 5, [
                CGColor(gray: 0.70, alpha: 1.0),
                CGColor(gray: 0.60, alpha: 1.0),
                CGColor(gray: 0.50, alpha: 1.0)
            ]),
            (120,90,-3, 8,-10, [
                CGColor(gray: 0.85, alpha: 1.0),
                CGColor(gray: 0.75, alpha: 1.0),
                CGColor(gray: 0.65, alpha: 1.0)
            ])
        ]
        let config = noteConfigs[layer]
        let scale = size.width / 200
        let noteWidth = config.0 * scale
        let noteHeight = config.1 * scale
        let rotation = config.2
        let offsetX = config.3 * scale
        let offsetY = config.4 * scale
        let colors = config.5

        ctx.translateBy(x: size.width/2 + offsetX, y: size.height/2 + offsetY)
        ctx.rotate(by: rotation * .pi / 180)

        let shadowOffsets: [CGSize] = [CGSize(width: 3, height: 6), CGSize(width: 3, height: 6), CGSize(width: 3, height: 6)]
        let shadowOpacities: [CGFloat] = [0.4, 0.3, 0.25]
        let shadowRadii: [CGFloat] = [8,6,4]
        ctx.setShadow(offset: CGSize(width: shadowOffsets[layer].width * scale, height: shadowOffsets[layer].height * scale),
                      blur: shadowRadii[layer] * scale,
                      color: CGColor(gray: 0, alpha: shadowOpacities[layer]))

        let noteRect = CGRect(x: -noteWidth/2, y: -noteHeight/2, width: noteWidth, height: noteHeight)
        let notePath = CGPath(roundedRect: noteRect, cornerWidth: 8 * scale, cornerHeight: 8 * scale, transform: nil)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0,0.5,1]) {
            ctx.addPath(notePath)
            ctx.clip()
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: -noteWidth/2, y: -noteHeight/2),
                                   end: CGPoint(x: noteWidth/2, y: noteHeight/2),
                                   options: [])
            ctx.resetClip()
        }

        // Outer strokes
        ctx.setLineWidth(2.5 * scale)
        ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.5))
        ctx.addPath(notePath)
        ctx.strokePath()

        if layer == 2 {
            ctx.setLineWidth(3 * scale)
            ctx.setStrokeColor(CGColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 0.85))
            ctx.addPath(notePath)
            ctx.strokePath()

            ctx.setLineWidth(1.5 * scale)
            ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.78))
            ctx.addPath(notePath)
            ctx.strokePath()
        } else {
            ctx.setLineWidth(1.5 * scale)
            ctx.setStrokeColor(CGColor(gray: 0.88, alpha: 0.35))
            ctx.addPath(notePath)
            ctx.strokePath()
        }

        // Guide lines
        ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.25))
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

if let cgImage = IconGenerator.createModernIcon() {
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: 1024, height: 1024)
    if let data = rep.representation(using: .png, properties: [:]) {
        let currentDir = FileManager.default.currentDirectoryPath
        let iconPath = "\(currentDir)/LiquidNotes/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
        do {
            try data.write(to: URL(fileURLWithPath: iconPath))
            print("✅ New modern app icon generated successfully (opaque).")
        } catch {
            print("❌ Failed to save icon: \(error)")
        }
    } else {
        print("❌ Could not encode PNG data")
    }
} else {
    print("❌ Failed to generate icon")
}