import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleTimerEnd(identifier: String, after interval: TimeInterval) async
    func cancel(identifiers: [String])
}

@MainActor
final class NotificationService: NotificationScheduling {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleTimerEnd(identifier: String, after interval: TimeInterval) async {
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "NO EXCUSE"
        content.body = "时间到了。你制造现实了吗？"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
