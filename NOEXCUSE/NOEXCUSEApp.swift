import SwiftData
import SwiftUI

@main
struct NOEXCUSEApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var viewModel: ActionViewModel

    init() {
        do {
            let container = try ModelContainer(for: ActionTask.self)
            modelContainer = container
            _viewModel = StateObject(wrappedValue: ActionViewModel(context: container.mainContext))
        } catch {
            fatalError("无法创建本地数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
