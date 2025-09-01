import Foundation

extension Date {
    /// Returns a short day-based distance string between self and now.
    /// Examples: "Today", "1d", "2d", "5d", or "-1d" (overdue indicator to be styled by caller).
    func ln_dayDistanceString(from reference: Date = Date()) -> String {
        let cal = Calendar.current
        let startSelf = cal.startOfDay(for: self)
        let startRef = cal.startOfDay(for: reference)
        let comps = cal.dateComponents([.day], from: startRef, to: startSelf)
        guard let days = comps.day else { return "" }
    if days == 0 { return "Today" }
    if days < 0 { return "Overdue" }
    return "\(days)d"
    }
}
