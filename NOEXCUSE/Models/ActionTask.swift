import Foundation
import SwiftData

enum TaskOutcome: String, Codable {
    case active
    case madeReality
    case escaped
}

@Model
final class ActionTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var elapsedBeforeCurrentRun: TimeInterval
    var runningSince: Date?
    var notificationIdentifier: String?
    var outcomeRawValue: String
    var resolvedAt: Date?
    var realityText: String?

    init(title: String, duration: TimeInterval = 25 * 60) {
        id = UUID()
        self.title = title
        createdAt = .now
        self.duration = duration
        elapsedBeforeCurrentRun = 0
        runningSince = nil
        notificationIdentifier = nil
        outcomeRawValue = TaskOutcome.active.rawValue
    }

    var outcome: TaskOutcome {
        get { TaskOutcome(rawValue: outcomeRawValue) ?? .active }
        set { outcomeRawValue = newValue.rawValue }
    }

    var isRunning: Bool {
        outcome == .active && runningSince != nil && remainingTime(at: .now) > 0
    }

    func elapsedTime(at date: Date) -> TimeInterval {
        let currentRun = runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return min(duration, elapsedBeforeCurrentRun + currentRun)
    }

    func remainingTime(at date: Date) -> TimeInterval {
        max(0, duration - elapsedTime(at: date))
    }

    func pause(at date: Date) {
        elapsedBeforeCurrentRun = elapsedTime(at: date)
        runningSince = nil
    }
}
