import SwiftUI

enum NotePriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"  
    case urgent = "urgent"
    
    var color: Color {
        switch self {
        case .low: return .blue.opacity(0.6)
        case .normal: return .clear
        case .high: return .orange.opacity(0.6)
        case .urgent: return .red.opacity(0.6)
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .normal: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle.fill"
        }
    }
}