import Foundation
import UserNotifications

enum NotificationScheduler {
    static let dailyReviewIdentifier = "ln.dailyReview"
    static func requestAuthIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }
    static func scheduleDailyReview(hour: Int) {
        requestAuthIfNeeded()
        cancelDailyReview()
        var date = DateComponents()
        date.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Daily Review"
        content.body = "Revisit today’s notes & overdue tasks."
        content.sound = .default
        let req = UNNotificationRequest(identifier: dailyReviewIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    static func cancelDailyReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReviewIdentifier])
    }
}