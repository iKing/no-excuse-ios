import Foundation
import SwiftData

struct DailyStats {
    let madeRealityCount: Int
    let escapedCount: Int
    let realityRecords: [ActionTask]

    var actionScore: Int { madeRealityCount * 10 }

    static let empty = DailyStats(
        madeRealityCount: 0,
        escapedCount: 0,
        realityRecords: []
    )
}

@MainActor
final class ActionViewModel: ObservableObject {
    @Published private(set) var activeTask: ActionTask?
    @Published private(set) var dailyStats = DailyStats.empty
    @Published private(set) var historyRecords: [ActionTask] = []
    @Published var errorMessage: String?

    private let context: ModelContext
    private let notifications: any NotificationScheduling
    private var notificationSchedulingTask: Task<Void, Never>?
    private var lastKnownDay = Calendar.current.startOfDay(for: .now)
    private let clockTolerance: TimeInterval = 5

    init(
        context: ModelContext,
        notifications: (any NotificationScheduling)? = nil
    ) {
        self.context = context
        self.notifications = notifications ?? NotificationService.shared
        refresh()
    }

    func refresh(snapshot: ClockSnapshot = .now) {
        refreshActiveTask()
        validateClockIntegrity(snapshot: snapshot)
        refreshDailyStats(now: snapshot.date)
        refreshHistory()
    }

    func refreshForClockTick(snapshot: ClockSnapshot = .now) {
        validateClockIntegrity(snapshot: snapshot)
        if Calendar.current.startOfDay(for: snapshot.date) != lastKnownDay {
            refreshDailyStats(now: snapshot.date)
        }
    }

    @discardableResult
    func createTask(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, activeTask == nil else { return false }

        let task = ActionTask(title: trimmed)
        context.insert(task)
        activeTask = task
        return save()
    }

    func startOrResume(snapshot: ClockSnapshot = .now) {
        guard let task = activeTask,
              task.outcome == .active,
              task.runningSince == nil,
              task.remainingTime(at: snapshot) > 0 else { return }

        task.begin(at: snapshot)
        let notificationIdentifier = "\(task.id.uuidString).\(UUID().uuidString)"
        task.notificationIdentifier = notificationIdentifier
        guard save() else { return }

        notificationSchedulingTask?.cancel()
        notificationSchedulingTask = Task { [weak self, weak task] in
            guard let self, let task else { return }
            let authorized = await notifications.requestAuthorization()
            guard authorized,
                  !Task.isCancelled,
                  activeTask?.id == task.id,
                  task.outcome == .active,
                  task.runningSince != nil,
                  task.notificationIdentifier == notificationIdentifier else { return }

            let currentSnapshot = ClockSnapshot.now
            guard !task.hasClockDiscontinuity(
                at: currentSnapshot,
                tolerance: clockTolerance
            ) else {
                interruptForClockDiscontinuity(task, snapshot: currentSnapshot)
                return
            }

            let currentRemaining = task.remainingTime(at: currentSnapshot)
            guard currentRemaining > 0 else { return }

            await notifications.scheduleTimerEnd(
                identifier: notificationIdentifier,
                after: currentRemaining
            )

            if Task.isCancelled
                || activeTask?.id != task.id
                || task.runningSince == nil
                || task.notificationIdentifier != notificationIdentifier {
                notifications.cancel(identifiers: [notificationIdentifier])
            }
        }
    }

    func pause(snapshot: ClockSnapshot = .now) {
        guard let task = activeTask, task.runningSince != nil else { return }
        task.pause(at: snapshot)
        cancelNotification(for: task)
        save()
    }

    func markMadeReality(_ text: String, snapshot: ClockSnapshot = .now) {
        guard let task = activeTask,
              validateClockIntegrity(snapshot: snapshot),
              task.remainingTime(at: snapshot) <= 0 else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        resolve(task, as: .madeReality, realityText: trimmed, snapshot: snapshot)
    }

    func markEscaped(snapshot: ClockSnapshot = .now) {
        guard let task = activeTask,
              validateClockIntegrity(snapshot: snapshot) else { return }
        resolve(task, as: .escaped, realityText: nil, snapshot: snapshot)
    }

    func deleteHistoryRecord(_ record: ActionTask, now: Date = .now) {
        guard record.outcome != .active else { return }
        context.delete(record)
        if save() {
            refreshDailyStats(now: now)
            refreshHistory()
        }
    }

    private func resolve(
        _ task: ActionTask,
        as outcome: TaskOutcome,
        realityText: String?,
        snapshot: ClockSnapshot
    ) {
        if task.runningSince != nil {
            task.pause(at: snapshot)
        }
        task.outcome = outcome
        task.resolvedAt = snapshot.date
        task.realityText = realityText
        cancelNotification(for: task)

        if save() {
            activeTask = nil
            refreshDailyStats(now: snapshot.date)
            refreshHistory()
        }
    }

    private func refreshActiveTask() {
        var descriptor = FetchDescriptor<ActionTask>(
            predicate: #Predicate { $0.outcomeRawValue == "active" },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1

        do {
            activeTask = try context.fetch(descriptor).first
        } catch {
            errorMessage = "无法读取当前行动：\(error.localizedDescription)"
        }
    }

    private func refreshDailyStats(now: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        lastKnownDay = start

        let descriptor = FetchDescriptor<ActionTask>(
            sortBy: [SortDescriptor(\.resolvedAt, order: .reverse)]
        )

        do {
            // SwiftData cannot reliably translate a force-unwrapped optional Date
            // inside #Predicate on every supported iOS version. Keep the fetch
            // simple and apply the day boundary in memory; an MVP has few records.
            let resolved = try context.fetch(descriptor).filter { task in
                guard let resolvedAt = task.resolvedAt else { return false }
                return resolvedAt >= start && resolvedAt < end
            }
            let madeReality = resolved.filter { $0.outcome == .madeReality }
            dailyStats = DailyStats(
                madeRealityCount: madeReality.count,
                escapedCount: resolved.filter { $0.outcome == .escaped }.count,
                realityRecords: madeReality
            )
        } catch {
            errorMessage = "无法读取今日记录：\(error.localizedDescription)"
        }
    }

    private func refreshHistory() {
        let descriptor = FetchDescriptor<ActionTask>(
            sortBy: [SortDescriptor(\.resolvedAt, order: .reverse)]
        )

        do {
            historyRecords = try context.fetch(descriptor).filter {
                $0.outcome != .active && $0.resolvedAt != nil
            }
        } catch {
            errorMessage = "无法读取历史记录：\(error.localizedDescription)"
        }
    }

    @discardableResult
    private func validateClockIntegrity(snapshot: ClockSnapshot) -> Bool {
        guard let task = activeTask, task.runningSince != nil else { return true }
        guard task.hasClockDiscontinuity(
            at: snapshot,
            tolerance: clockTolerance
        ) else { return true }

        interruptForClockDiscontinuity(task, snapshot: snapshot)
        return false
    }

    private func interruptForClockDiscontinuity(
        _ task: ActionTask,
        snapshot: ClockSnapshot
    ) {
        task.pause(at: snapshot)
        cancelNotification(for: task)
        save()
        errorMessage = "检测到系统时间跳变或设备重启。当前行动已安全暂停；修改日期不能推进计时。"
    }

    private func cancelNotification(for task: ActionTask) {
        notificationSchedulingTask?.cancel()
        notificationSchedulingTask = nil

        let identifiers = [task.notificationIdentifier, task.id.uuidString]
            .compactMap { $0 }
        task.notificationIdentifier = nil
        notifications.cancel(identifiers: identifiers)
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            errorMessage = "保存失败：\(error.localizedDescription)"
            refresh()
            return false
        }
    }
}
