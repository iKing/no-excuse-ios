import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: ActionViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var isCreatingTask = false
    @State private var isConfirmingEscape = false
    @State private var isShowingHistory = false

    var body: some View {
        ZStack {
            Color.noExcuseBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.bottom, 28)

                    if let task = viewModel.activeTask {
                        ActiveTaskView(
                            task: task,
                            onStart: { viewModel.startOrResume() },
                            onPause: { viewModel.pause() },
                            onMadeReality: { text in viewModel.markMadeReality(text) },
                            onEscape: { isConfirmingEscape = true }
                        )
                    } else {
                        EmptyTaskView { isCreatingTask = true }
                    }

                    DailyStatsView(stats: viewModel.dailyStats)
                        .padding(.top, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $isCreatingTask) {
            CreateTaskView { title in
                if viewModel.createTask(title: title) {
                    isCreatingTask = false
                }
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $isShowingHistory) {
            HistoryView(
                records: viewModel.historyRecords,
                onDelete: { viewModel.deleteHistoryRecord($0) }
            )
        }
        .confirmationDialog(
            "放弃不是暂停。它会被记作一次逃跑。",
            isPresented: $isConfirmingEscape,
            titleVisibility: .visible
        ) {
            Button("我逃跑了", role: .destructive) {
                viewModel.markEscaped()
            }
            Button("继续面对", role: .cancel) {}
        }
        .alert("出错了", isPresented: errorBinding) {
            Button("知道了") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                viewModel.refreshForClockTick()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("NO EXCUSE")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(Color.noExcuseRed)

                Text("别想了。动手。")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                isShowingHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.noExcusePanel)
                    .overlay(Rectangle().stroke(Color.noExcuseBorder, lineWidth: 1))
            }
            .accessibilityLabel("查看历史")
            .padding(.trailing, 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text("今日行动值")
                    .font(.caption)
                    .foregroundStyle(Color.noExcuseMuted)
                Text("\(viewModel.dailyStats.actionScore)")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

extension Color {
    static let noExcuseBlack = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let noExcusePanel = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let noExcuseBorder = Color.white.opacity(0.10)
    static let noExcuseMuted = Color.white.opacity(0.48)
    static let noExcuseRed = Color(red: 0.93, green: 0.16, blue: 0.14)
}
