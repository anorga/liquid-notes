import Foundation
import Combine

@MainActor
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    private init() {}
    @Published private(set) var counters: [String:Int] = [:]
    private let storeKey = "ln.analytics.counters"
    func increment(_ key: String) {
        loadIfNeeded()
        counters[key, default: 0] += 1
        persist()
    }
    func value(_ key: String) -> Int { loadIfNeeded(); return counters[key, default: 0] }
    private var loaded = false
    private func loadIfNeeded() {
        guard !loaded else { return }
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let dict = try? JSONDecoder().decode([String:Int].self, from: data) { counters = dict }
        loaded = true
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(counters) { UserDefaults.standard.set(data, forKey: storeKey) }
    }
}