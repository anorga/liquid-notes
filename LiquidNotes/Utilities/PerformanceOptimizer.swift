import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
final class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    @Published var isOptimizationEnabled = true
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var thermalStateObserver: NSObjectProtocol?
    private let backgroundQueue = DispatchQueue(label: "PerformanceOptimizer.background", qos: .utility)
    
    private init() {
        setupThermalStateMonitoring()
    }
    
    deinit {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupThermalStateMonitoring() {
        thermalState = ProcessInfo.processInfo.thermalState
        
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                PerformanceOptimizer.shared.thermalState = ProcessInfo.processInfo.thermalState
                PerformanceOptimizer.shared.adjustPerformanceBasedOnThermalState()
            }
        }
    }
    
    private func adjustPerformanceBasedOnThermalState() {
        switch thermalState {
        case .nominal:
            isOptimizationEnabled = false
            MotionManager.shared.startTracking()
            
        case .fair:
            isOptimizationEnabled = true
            
        case .serious, .critical:
            isOptimizationEnabled = true
            MotionManager.shared.stopTracking()
            
        @unknown default:
            isOptimizationEnabled = true
        }
    }
    
    nonisolated var shouldReduceAnimations: Bool {
        ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
    }
    
    nonisolated var shouldUseSimplifiedGlass: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .fair || state == .serious || state == .critical
    }
    
    nonisolated var shouldReduceGIFFrameRate: Bool {
        ProcessInfo.processInfo.thermalState != .nominal
    }
    
    func performBackgroundTask<T>(_ task: @escaping () throws -> T, completion: @MainActor @escaping (Result<T, Error>) -> Void) {
        backgroundQueue.async {
            do {
                let result = try task()
                Task { @MainActor in
                    completion(.success(result))
                }
            } catch {
                Task { @MainActor in
                    completion(.failure(error))
                }
            }
        }
    }
    
    func throttle<T>(interval: TimeInterval, latest: Bool = true, action: @escaping () -> T) -> (() -> Void) {
        var lastExecutionTime: TimeInterval = 0
        var workItem: DispatchWorkItem?
        
        return {
            let currentTime = CACurrentMediaTime()
            let timeSinceLastExecution = currentTime - lastExecutionTime
            
            if timeSinceLastExecution >= interval {
                lastExecutionTime = currentTime
                _ = action()
            } else if latest {
                workItem?.cancel()
                workItem = DispatchWorkItem {
                    lastExecutionTime = CACurrentMediaTime()
                    _ = action()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (interval - timeSinceLastExecution), execute: workItem!)
            }
        }
    }
    
    func memoryWarningCleanup() {
        NotificationCenter.default.post(name: .performanceOptimizationCleanup, object: nil)
    }
}

extension Notification.Name {
    static let performanceOptimizationCleanup = Notification.Name("performanceOptimizationCleanup")
}

extension View {
    func optimizedForThermalState() -> some View {
        let optimizer = PerformanceOptimizer.shared
        
        return Group {
            if optimizer.shouldReduceAnimations {
                self.animation(nil, value: UUID())
            } else {
                self
            }
        }
    }
}
