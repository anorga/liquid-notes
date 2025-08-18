//
//  MotionManager.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import CoreMotion
import SwiftUI
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var data = MotionData()
    @Published var isActive = false
    
    // Convenience property for glass effects
    var motionData: MotionData {
        return data
    }
    
    struct MotionData {
        var pitch: Double = 0
        var roll: Double = 0
        var yaw: Double = 0
        var rotationRate = CMRotationRate()
        var gravity = CMAcceleration()
        
        var isSignificantMotion: Bool {
            abs(pitch) > 0.1 || abs(roll) > 0.1 || abs(yaw) > 0.1
        }
    }
    
    init() {
        setupMotionManager()
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
    }
    
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS for smooth animations
    }
    
    func startTracking() {
        guard !isActive && motionManager.isDeviceMotionAvailable else { return }
        
        isActive = true
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("Motion update error: \(error)")
                }
                return
            }
            
            self.updateMotionData(motion)
        }
    }
    
    func stopTracking() {
        guard isActive else { return }
        
        isActive = false
        motionManager.stopDeviceMotionUpdates()
        
        // Reset motion data
        data = MotionData()
    }
    
    private func updateMotionData(_ motion: CMDeviceMotion) {
        data.pitch = motion.attitude.pitch
        data.roll = motion.attitude.roll
        data.yaw = motion.attitude.yaw
        data.rotationRate = motion.rotationRate
        data.gravity = motion.gravity
    }
    
    // MARK: - Utility Methods
    
    func normalizedMotionValues() -> (x: Double, y: Double) {
        // Normalize motion values to -1.0 to 1.0 range for UI effects
        let normalizedX = max(-1.0, min(1.0, data.roll * 2.0))
        let normalizedY = max(-1.0, min(1.0, data.pitch * 2.0))
        
        return (normalizedX, normalizedY)
    }
    
    func motionIntensity() -> Double {
        // Calculate overall motion intensity (0.0 to 1.0)
        let pitchIntensity = abs(data.pitch) / .pi
        let rollIntensity = abs(data.roll) / .pi
        let yawIntensity = abs(data.yaw) / .pi
        
        return min(1.0, (pitchIntensity + rollIntensity + yawIntensity) / 3.0)
    }
    
    // MARK: - Alternative Method Names for Compatibility
    
    func startMotionUpdates() {
        startTracking()
    }
    
    func stopMotionUpdates() {
        stopTracking()
    }
}