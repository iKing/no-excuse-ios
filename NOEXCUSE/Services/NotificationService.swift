import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func scheduleTimerEnd(for task: ActionTask, after interval: TimeInterval) async {
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
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(for task: ActionTask) {
        let identifier = task.id.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
