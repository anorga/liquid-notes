//
//  HapticManager.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for better responsiveness
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Note Interactions
    
    func noteCreated() {
        mediumImpact.impactOccurred()
    }
    
    func noteSelected() {
        lightImpact.impactOccurred()
    }
    
    func noteDeleted() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func noteMoved() {
        lightImpact.impactOccurred()
    }
    
    func noteDropped() {
        mediumImpact.impactOccurred()
    }

    func noteFavorited() {
        mediumImpact.impactOccurred(intensity: 0.7)
    }

    func noteArchived() {
        heavyImpact.impactOccurred(intensity: 0.9)
    }
    
    // MARK: - Glass Effects
    
    func glassThemeChanged() {
        selectionFeedback.selectionChanged()
    }
    
    func glassInteraction() {
        lightImpact.impactOccurred()
    }
    
    // MARK: - General UI
    
    func buttonTapped() {
        lightImpact.impactOccurred()
    }
    
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    // MARK: - Static Convenience Methods
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            HapticManager.shared.lightImpact.impactOccurred()
        case .medium:
            HapticManager.shared.mediumImpact.impactOccurred()
        case .heavy:
            HapticManager.shared.heavyImpact.impactOccurred()
        case .soft:
            HapticManager.shared.lightImpact.impactOccurred() // Fallback to light for soft
        case .rigid:
            HapticManager.shared.heavyImpact.impactOccurred() // Fallback to heavy for rigid
        @unknown default:
            HapticManager.shared.lightImpact.impactOccurred()
        }
    }
}