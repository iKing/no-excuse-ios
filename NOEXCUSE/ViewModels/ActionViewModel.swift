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
    @Published var errorMessage: String?

    private let context: ModelContext
    private let notifications: NotificationService
    private var lastKnownDay = Calendar.current.startOfDay(for: .now)

    init(context: ModelContext, notifications: NotificationService = .shared) {
        self.context = context
        self.notifications = notifications
        refresh()
    }

    func refresh(now: Date = .now) {
        refreshActiveTask()
        refreshDailyStats(now: now)
    }

    func refreshForClockTick(now: Date) {
        if Calendar.current.startOfDay(for: now) != lastKnownDay {
            refreshDailyStats(now: now)
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

    func startOrResume(now: Date = .now) {
        guard let task = activeTask,
              task.outcome == .active,
              task.runningSince == nil,
              task.remainingTime(at: now) > 0 else { return }

        task.runningSince = now
        guard save() else { return }

        Task {
            await notifications.requestAuthorization()
            let currentRemaining = task.remainingTime(at: .now)
            await notifications.scheduleTimerEnd(for: task, after: currentRemaining)
        }
    }

    func pause(now: Date = .now) {
        guard let task = activeTask, task.runningSince != nil else { return }
        task.pause(at: now)
        notifications.cancel(for: task)
        save()
    }

    func markMadeReality(_ text: String, now: Date = .now) {
        guard let task = activeTask,
              task.remainingTime(at: now) <= 0 else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        resolve(task, as: .madeReality, realityText: trimmed, now: now)
    }

    func markEscaped(now: Date = .now) {
        guard let task = activeTask else { return }
        resolve(task, as: .escaped, realityText: nil, now: now)
    }

    private func resolve(
        _ task: ActionTask,
        as outcome: TaskOutcome,
        realityText: String?,
        now: Date
    ) {
        if task.runningSince != nil {
            task.pause(at: now)
        }
        task.outcome = outcome
        task.resolvedAt = now
        task.realityText = realityText
        notifications.cancel(for: task)

        if save() {
            activeTask = nil
            refreshDailyStats(now: now)
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
