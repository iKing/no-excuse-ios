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
    func testTimerUsesTimestampsAcrossPauseAndResume() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let task = ActionTask(title: "交付原型")

        task.runningSince = start
        XCTAssertEqual(task.remainingTime(at: start.addingTimeInterval(300)), 1_200, accuracy: 0.001)

        task.pause(at: start.addingTimeInterval(300))
        XCTAssertNil(task.runningSince)
        XCTAssertEqual(task.elapsedBeforeCurrentRun, 300, accuracy: 0.001)

        task.runningSince = start.addingTimeInterval(600)
        XCTAssertEqual(task.remainingTime(at: start.addingTimeInterval(660)), 1_140, accuracy: 0.001)
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
        viewModel.startOrResume(now: start)

        viewModel.markMadeReality("提前冒充完成", now: start.addingTimeInterval(9))
        XCTAssertNotNil(viewModel.activeTask)

        viewModel.markMadeReality("   ", now: start.addingTimeInterval(10))
        XCTAssertNotNil(viewModel.activeTask)

        viewModel.markMadeReality("提交了可运行版本", now: start.addingTimeInterval(10))
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
        viewModel.markEscaped(now: dayOne)
        XCTAssertEqual(viewModel.dailyStats.escapedCount, 1)

        viewModel.refreshForClockTick(now: dayTwo)
        XCTAssertEqual(viewModel.dailyStats.escapedCount, 0)
        XCTAssertEqual(viewModel.dailyStats.actionScore, 0)
    }

    func testPausingDuringAuthorizationDoesNotScheduleNotification() async throws {
        let spy = NotificationSpy()
        spy.authorizationDelayNanoseconds = 100_000_000
        let (viewModel, _) = try makeViewModel(notifications: spy)
        let start = Date.now

        XCTAssertTrue(viewModel.createTask(title: "等待授权"))
        viewModel.startOrResume(now: start)
        viewModel.pause(now: start.addingTimeInterval(1))

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(spy.scheduledIdentifiers.isEmpty)
        XCTAssertNil(viewModel.activeTask?.notificationIdentifier)
        XCTAssertFalse(spy.cancelledIdentifiers.isEmpty)
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
