import Foundation
import SwiftData

struct ClockSnapshot: Equatable {
    let date: Date
    let systemUptime: TimeInterval

    static var now: ClockSnapshot {
        ClockSnapshot(
            date: .now,
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
    }
}

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
    var runningSystemUptime: TimeInterval?
    var clockAnchorDate: Date?
    var clockAnchorSystemUptime: TimeInterval?
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
        runningSystemUptime = nil
        clockAnchorDate = nil
        clockAnchorSystemUptime = nil
        notificationIdentifier = nil
        outcomeRawValue = TaskOutcome.active.rawValue
    }

    var outcome: TaskOutcome {
        get { TaskOutcome(rawValue: outcomeRawValue) ?? .active }
        set { outcomeRawValue = newValue.rawValue }
    }

    var isRunning: Bool {
        outcome == .active && runningSince != nil && remainingTime(at: ClockSnapshot.now) > 0
    }

    func elapsedTime(at snapshot: ClockSnapshot) -> TimeInterval {
        guard runningSince != nil else { return min(duration, elapsedBeforeCurrentRun) }
        guard let runningSystemUptime,
              snapshot.systemUptime >= runningSystemUptime else {
            // A missing or reset monotonic anchor is ambiguous. Freeze until the
            // view model safely pauses the action instead of trusting wall time.
            return min(duration, elapsedBeforeCurrentRun)
        }

        let currentRun = snapshot.systemUptime - runningSystemUptime
        return min(duration, elapsedBeforeCurrentRun + currentRun)
    }

    func remainingTime(at snapshot: ClockSnapshot) -> TimeInterval {
        max(0, duration - elapsedTime(at: snapshot))
    }

    func begin(at snapshot: ClockSnapshot) {
        runningSince = snapshot.date
        runningSystemUptime = snapshot.systemUptime
        clockAnchorDate = snapshot.date
        clockAnchorSystemUptime = snapshot.systemUptime
    }

    func hasClockDiscontinuity(
        at snapshot: ClockSnapshot,
        tolerance: TimeInterval
    ) -> Bool {
        guard runningSince != nil else { return false }
        guard let clockAnchorDate, let clockAnchorSystemUptime else { return true }

        let uptimeDelta = snapshot.systemUptime - clockAnchorSystemUptime
        guard uptimeDelta >= 0 else { return true }

        let expectedDate = clockAnchorDate.addingTimeInterval(uptimeDelta)
        return abs(snapshot.date.timeIntervalSince(expectedDate)) > tolerance
    }

    func pause(at snapshot: ClockSnapshot) {
        elapsedBeforeCurrentRun = elapsedTime(at: snapshot)
        runningSince = nil
        runningSystemUptime = nil
        clockAnchorDate = nil
        clockAnchorSystemUptime = nil
    }
}
