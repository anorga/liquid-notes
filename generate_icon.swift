#!/usr/bin/env swift

import Foundation
import CoreGraphics
import AppKit
import CryptoKit

struct IconGenerator {
    // Attempt to load a user-provided 1024x1024 (or any size) PNG named icon_source.png
    static func loadSourceIcon() -> CGImage? {
        let fm = FileManager.default
        let path = fm.currentDirectoryPath + "/icon_source.png"
        if fm.fileExists(atPath: path), let nsImage = NSImage(contentsOf: URL(fileURLWithPath: path)) {
            // Normalize to 1024x1024 canvas (keeping aspect, letterboxing with transparency)
            guard let rep = nsImage.representations.first else { return nil }
            let target: CGFloat = 1024
            let w = CGFloat(rep.pixelsWide)
            let h = CGFloat(rep.pixelsHigh)
            if let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                if w == target && h == target { return cg }
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                guard let ctx = CGContext(data: nil, width: Int(target), height: Int(target), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return cg }
                ctx.clear(CGRect(x: 0, y: 0, width: target, height: target))
                let env = ProcessInfo.processInfo.environment
                let cropFill = env["ICON_CROP_FILL"] == "1"
                // scaleForLetterbox fits entire image; scaleForFill covers and crops
                let scaleFit = min(target / w, target / h)
                let scaleFill = max(target / w, target / h)
                let scale = cropFill ? scaleFill : scaleFit
                let drawW = w * scale
                let drawH = h * scale
                // Center position; if cropFill true, some parts will be clipped when drawn outside canvas
                let drawRect = CGRect(x: (target - drawW)/2, y: (target - drawH)/2, width: drawW, height: drawH)
                ctx.interpolationQuality = .high
                ctx.draw(cg, in: drawRect)
                return ctx.makeImage()
            }
        }
        return nil
    }
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

// Determine asset directory robustly relative to script location and CWD
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let scriptDir = scriptURL.deletingLastPathComponent()
let fm = FileManager.default
let candidatePaths: [URL] = [
    scriptDir.appendingPathComponent("LiquidNotes/Assets.xcassets/AppIcon.appiconset"),
    scriptDir.deletingLastPathComponent().appendingPathComponent("LiquidNotes/Assets.xcassets/AppIcon.appiconset"),
    URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("LiquidNotes/Assets.xcassets/AppIcon.appiconset"),
    URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
]
let assetDir = candidatePaths.first { fm.fileExists(atPath: $0.path) } ?? candidatePaths[2]
print("ℹ️ Using asset directory: \(assetDir.path)")

let usedSource = IconGenerator.loadSourceIcon() != nil
let baseImage: CGImage? = IconGenerator.loadSourceIcon() ?? IconGenerator.createModernIcon()
print("ℹ️ Source mode: \(usedSource ? "icon_source.png" : "procedural fallback")")

if let cgImage = baseImage {
    let explicitList: [Int] = [20,29,40,58,60,76,80,87,120,152,167,180,1024]
    func resized(_ image: CGImage, to pixel: Int) -> CGImage? {
        if image.width == pixel { return image }
        guard let ctx = CGContext(data: nil,
                                  width: pixel,
                                  height: pixel,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixel, height: pixel))
        return ctx.makeImage()
    }

    let encoder = { (data: Data) -> String in
        if #available(macOS 10.15, *) {
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12) + "…"
        } else { return "hash-n/a" }
    }

    var summary: [String] = []
    for p in explicitList {
        guard let scaled = resized(cgImage, to: p) else { continue }
        let rep = NSBitmapImageRep(cgImage: scaled)
        guard let data = rep.representation(using: .png, properties: [:]) else { continue }
        let name = "icon-\(p).png"
        let pathURL = assetDir.appendingPathComponent(name)
        do {
            try data.write(to: pathURL, options: .atomic)
            summary.append("\(name)(\(data.count/1024)KB, sha \(encoder(data)))")
        } catch {
            fputs("Failed writing \(name): \(error)\n", stderr)
        }
    }
    print("✅ Regenerated: \n  • " + summary.joined(separator: "\n  • "))
    print("Done. If Xcode still shows old artwork, Clean Build Folder (Shift+Cmd+K) and reinstall, or bump build number.")
} else {
    print("❌ Failed to generate icon (no usable base image)")
}