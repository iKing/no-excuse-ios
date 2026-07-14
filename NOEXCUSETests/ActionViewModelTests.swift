import SwiftData
import XCTest
@testable import NOEXCUSE

@MainActor
private final class NotificationSpy: NotificationScheduling {
    var authorizationDelayNanoseconds: UInt64 = 0
    var authorizationResult = true
    private(set) var scheduledIdentifiers: [String] = []
    private(set) var cancelledIdentifiers: [String] = []

    func requestAuthorization() async -> Bool {
        if authorizationDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: authorizationDelayNanoseconds)
        }
        return authorizationResult
    }

    func scheduleTimerEnd(identifier: String, after interval: TimeInterval) async {
        scheduledIdentifiers.append(identifier)
    }

    func cancel(identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }
}

@MainActor
final class ActionViewModelTests: XCTestCase {
    func testTimerUsesMonotonicClockAcrossPauseAndResume() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = ActionTask(title: "交付原型")
        let firstStart = ClockSnapshot(date: start, systemUptime: 1_000)

        task.begin(at: firstStart)
        XCTAssertEqual(
            task.remainingTime(at: ClockSnapshot(
                date: start.addingTimeInterval(86_400),
                systemUptime: 1_300
            )),
            1_200,
            accuracy: 0.001
        )

        task.pause(at: ClockSnapshot(
            date: start.addingTimeInterval(300),
            systemUptime: 1_300
        ))
        XCTAssertNil(task.runningSince)
        XCTAssertEqual(task.elapsedBeforeCurrentRun, 300, accuracy: 0.001)

        task.begin(at: ClockSnapshot(
            date: start.addingTimeInterval(600),
            systemUptime: 1_600
        ))
        XCTAssertEqual(
            task.remainingTime(at: ClockSnapshot(
                date: start.addingTimeInterval(660),
                systemUptime: 1_660
            )),
            1_140,
            accuracy: 0.001
        )
    }

    func testOnlyOneActiveTaskCanBeCreated() throws {
        let (viewModel, _) = try makeViewModel()

        XCTAssertTrue(viewModel.createTask(title: "第一件事"))
        XCTAssertFalse(viewModel.createTask(title: "第二件事"))
        XCTAssertEqual(viewModel.activeTask?.title, "第一件事")
    }

    func testRealityRequiresElapsedTimerAndNonemptyEvidence() throws {
        let (viewModel, context) = try makeViewModel()
        let start = Date.now

        XCTAssertTrue(viewModel.createTask(title: "提交代码"))
        viewModel.activeTask?.duration = 10
        try context.save()
        viewModel.startOrResume(snapshot: ClockSnapshot(date: start, systemUptime: 1_000))

        viewModel.markMadeReality(
            "提前冒充完成",
            snapshot: ClockSnapshot(
                date: start.addingTimeInterval(9),
                systemUptime: 1_009
            )
        )
        XCTAssertNotNil(viewModel.activeTask)

        viewModel.markMadeReality(
            "   ",
            snapshot: ClockSnapshot(
                date: start.addingTimeInterval(10),
                systemUptime: 1_010
            )
        )
        XCTAssertNotNil(viewModel.activeTask)

        viewModel.markMadeReality(
            "提交了可运行版本",
            snapshot: ClockSnapshot(
                date: start.addingTimeInterval(10),
                systemUptime: 1_010
            )
        )
        XCTAssertNil(viewModel.activeTask)
        XCTAssertEqual(viewModel.dailyStats.madeRealityCount, 1)
        XCTAssertEqual(viewModel.dailyStats.actionScore, 10)
    }

    func testDailyStatsResetWhenClockCrossesMidnight() throws {
        let (viewModel, _) = try makeViewModel()
        let calendar = Calendar.current
        let dayOne = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 14,
            hour: 12
        ))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!

        XCTAssertTrue(viewModel.createTask(title: "一次逃跑"))
        viewModel.markEscaped(snapshot: ClockSnapshot(date: dayOne, systemUptime: 1_000))
        XCTAssertEqual(viewModel.dailyStats.escapedCount, 1)

        viewModel.refreshForClockTick(snapshot: ClockSnapshot(
            date: dayTwo,
            systemUptime: 1_001
        ))
        XCTAssertEqual(viewModel.dailyStats.escapedCount, 0)
        XCTAssertEqual(viewModel.dailyStats.actionScore, 0)
    }

    func testPausingDuringAuthorizationDoesNotScheduleNotification() async throws {
        let spy = NotificationSpy()
        spy.authorizationDelayNanoseconds = 100_000_000
        let (viewModel, _) = try makeViewModel(notifications: spy)
        let start = Date.now

        XCTAssertTrue(viewModel.createTask(title: "等待授权"))
        viewModel.startOrResume(snapshot: ClockSnapshot(date: start, systemUptime: 1_000))
        viewModel.pause(snapshot: ClockSnapshot(
            date: start.addingTimeInterval(1),
            systemUptime: 1_001
        ))

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(spy.scheduledIdentifiers.isEmpty)
        XCTAssertNil(viewModel.activeTask?.notificationIdentifier)
        XCTAssertFalse(spy.cancelledIdentifiers.isEmpty)
    }

    func testChangingWallClockPausesWithoutAdvancingTimer() throws {
        let spy = NotificationSpy()
        let (viewModel, _) = try makeViewModel(notifications: spy)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.createTask(title: "不能靠改时间完成"))
        viewModel.startOrResume(snapshot: ClockSnapshot(date: start, systemUptime: 10_000))

        viewModel.refreshForClockTick(snapshot: ClockSnapshot(
            date: start.addingTimeInterval(86_401),
            systemUptime: 10_001
        ))

        let task = try XCTUnwrap(viewModel.activeTask)
        XCTAssertNil(task.runningSince)
        XCTAssertEqual(task.elapsedBeforeCurrentRun, 1, accuracy: 0.001)
        XCTAssertEqual(
            task.remainingTime(at: ClockSnapshot(
                date: start.addingTimeInterval(86_401),
                systemUptime: 10_001
            )),
            1_499,
            accuracy: 0.001
        )
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(spy.cancelledIdentifiers.isEmpty)
    }

    func testSystemUptimeResetSafelyPausesTimer() throws {
        let (viewModel, _) = try makeViewModel()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.createTask(title: "重启后暂停"))
        viewModel.startOrResume(snapshot: ClockSnapshot(date: start, systemUptime: 10_000))
        viewModel.refreshForClockTick(snapshot: ClockSnapshot(
            date: start.addingTimeInterval(30),
            systemUptime: 20
        ))

        XCTAssertNil(viewModel.activeTask?.runningSince)
        XCTAssertEqual(viewModel.activeTask?.elapsedBeforeCurrentRun ?? -1, 0, accuracy: 0.001)
    }

    func testHistoryCanBeReadAndDeleted() throws {
        let (viewModel, context) = try makeViewModel()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.createTask(title: "会进入历史"))
        viewModel.markEscaped(snapshot: ClockSnapshot(date: now, systemUptime: 1_000))

        let record = try XCTUnwrap(viewModel.historyRecords.first)
        XCTAssertEqual(record.title, "会进入历史")
        viewModel.deleteHistoryRecord(record, now: now)

        XCTAssertTrue(viewModel.historyRecords.isEmpty)
        let storedRecords = try context.fetch(FetchDescriptor<ActionTask>())
        XCTAssertTrue(storedRecords.isEmpty)
    }

    private func makeViewModel(
        notifications: (any NotificationScheduling)? = nil
    ) throws -> (ActionViewModel, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActionTask.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let viewModel = ActionViewModel(
            context: context,
            notifications: notifications ?? NotificationSpy()
        )
        return (viewModel, context)
    }
}
