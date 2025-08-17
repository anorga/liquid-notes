//
//  GlassEffectsViewModel.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftUI
import CoreMotion

@Observable
class GlassEffectsViewModel {
    private var motionManager = CMMotionManager()
    
    var isMotionEnabled = true
    var motionIntensity: Double = 1.0
    var currentTheme = GlassTheme.defaultThemes[0]
    
    // Motion data for glass effects
    var pitch: Double = 0
    var roll: Double = 0
    var yaw: Double = 0
    
    init() {
        setupMotionTracking()
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: - Motion Tracking
    
    func setupMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, self.isMotionEnabled else { return }
            
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw
        }
    }
    
    func stopMotionTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func toggleMotionTracking() {
        isMotionEnabled.toggle()
        
        if isMotionEnabled {
            setupMotionTracking()
        } else {
            // Reset motion values when disabled
            pitch = 0
            roll = 0
            yaw = 0
        }
    }
    
    // MARK: - Glass Effect Calculations
    
    func glassOffset(for theme: GlassTheme) -> CGSize {
        guard isMotionEnabled else { return .zero }
        
        let intensity = theme.motionResponseIntensity * motionIntensity
        let maxOffset: Double = 10.0
        
        let offsetX = sin(roll) * maxOffset * intensity
        let offsetY = sin(pitch) * maxOffset * intensity
        
        return CGSize(width: offsetX, height: offsetY)
    }
    
    func highlightOpacity(for theme: GlassTheme) -> Double {
        guard isMotionEnabled && theme.reflectionEnabled else {
            return theme.highlightIntensity * 0.3
        }
        
        // Calculate highlight based on device orientation
        let baseIntensity = theme.highlightIntensity
        let motionFactor = abs(sin(pitch)) + abs(sin(roll))
        
        return min(baseIntensity * (0.5 + motionFactor * 0.5), 1.0)
    }
    
    func highlightOffset(for theme: GlassTheme) -> CGSize {
        guard isMotionEnabled && theme.reflectionEnabled else { return .zero }
        
        let intensity = theme.motionResponseIntensity * motionIntensity
        let maxOffset: Double = 20.0
        
        let offsetX = -sin(roll) * maxOffset * intensity
        let offsetY = -sin(pitch) * maxOffset * intensity
        
        return CGSize(width: offsetX, height: offsetY)
    }
    
    // MARK: - Theme Management
    
    func setTheme(_ theme: GlassTheme) {
        currentTheme = theme
    }
    
    func availableThemes(includePremium: Bool = false) -> [GlassTheme] {
        if includePremium {
            return GlassTheme.defaultThemes
        } else {
            return GlassTheme.defaultThemes.filter { !$0.isPremium }
        }
    }
}