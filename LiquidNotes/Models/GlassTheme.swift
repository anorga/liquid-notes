//
//  GlassTheme.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import Foundation

struct GlassTheme: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let baseOpacity: Double
    let blurRadius: Double
    let tintColor: Color
    let highlightIntensity: Double
    let reflectionEnabled: Bool
    let motionResponseIntensity: Double
    let isPremium: Bool
    
    static let defaultThemes: [GlassTheme] = [
        GlassTheme(
            id: "clear",
            name: "Clear Crystal",
            baseOpacity: 0.1,
            blurRadius: 10.0,
            tintColor: .clear,
            highlightIntensity: 0.3,
            reflectionEnabled: true,
            motionResponseIntensity: 1.0,
            isPremium: false
        ),
        GlassTheme(
            id: "frosted",
            name: "Frosted Glass",
            baseOpacity: 0.3,
            blurRadius: 15.0,
            tintColor: .white.opacity(0.1),
            highlightIntensity: 0.2,
            reflectionEnabled: false,
            motionResponseIntensity: 0.8,
            isPremium: false
        ),
        GlassTheme(
            id: "tinted",
            name: "Ocean Tint",
            baseOpacity: 0.2,
            blurRadius: 12.0,
            tintColor: .blue.opacity(0.15),
            highlightIntensity: 0.4,
            reflectionEnabled: true,
            motionResponseIntensity: 1.2,
            isPremium: false
        ),
        GlassTheme(
            id: "iridescent",
            name: "Iridescent",
            baseOpacity: 0.15,
            blurRadius: 8.0,
            tintColor: .purple.opacity(0.1),
            highlightIntensity: 0.6,
            reflectionEnabled: true,
            motionResponseIntensity: 1.5,
            isPremium: true
        )
    ]
    
    static func theme(for id: String) -> GlassTheme {
        defaultThemes.first { $0.id == id } ?? defaultThemes[0]
    }
}