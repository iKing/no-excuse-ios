import SwiftData
import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct NOEXCUSEApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @StateObject private var viewModel: ActionViewModel

    init() {
        let container: ModelContainer
        var startupError: String?

        do {
            container = try ModelContainer(for: ActionTask.self)
        } catch {
            do {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(
                    for: ActionTask.self,
                    configurations: configuration
                )
                startupError = "本地数据库无法打开，已进入临时模式；本次行动不会永久保存。\n\(error.localizedDescription)"
            } catch {
                fatalError("无法创建本地数据库：\(error.localizedDescription)")
            }
        }

        let actionViewModel = ActionViewModel(context: container.mainContext)
        actionViewModel.errorMessage = startupError
        modelContainer = container
        _viewModel = StateObject(wrappedValue: actionViewModel)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
