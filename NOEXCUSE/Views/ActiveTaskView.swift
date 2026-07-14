import SwiftUI

struct ActiveTaskView: View {
    let task: ActionTask
    let onStart: () -> Void
    let onPause: () -> Void
    let onMadeReality: (String) -> Void
    let onEscape: () -> Void

    @State private var realityText = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = task.remainingTime(at: ClockSnapshot(
                date: context.date,
                systemUptime: ProcessInfo.processInfo.systemUptime
            ))
            let isFinished = remaining <= 0

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("唯一行动")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(Color.noExcuseRed)

                    Text(task.title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.noExcusePanel)
                .overlay(
                    Rectangle()
                        .stroke(Color.noExcuseBorder, lineWidth: 1)
                )

                timerSection(remaining: remaining, isFinished: isFinished)
                    .padding(.top, 36)

                if isFinished {
                    outcomeSection
                        .padding(.top, 30)
                } else {
                    controls
                        .padding(.top, 30)
                }
            }
        }
    }

    private func timerSection(remaining: TimeInterval, isFinished: Bool) -> some View {
        VStack(spacing: 9) {
            Text(timeString(remaining))
                .font(.system(size: 76, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(isFinished ? Color.noExcuseRed : .white)
                .contentTransition(.numericText())

            Text(isFinished ? "时间到了。你制造现实了吗？" : statusText)
                .font(.system(size: 14, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(isFinished ? Color.noExcuseRed : Color.noExcuseMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusText: String {
        if task.runningSince != nil { return "现实窗口正在关闭" }
        if task.elapsedBeforeCurrentRun > 0 { return "你停下了。继续。" }
        return "25 分钟。只做这一件事。"
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button(action: task.runningSince == nil ? onStart : onPause) {
                Text(task.runningSince == nil
                     ? (task.elapsedBeforeCurrentRun > 0 ? "继续" : "开始行动")
                     : "暂停")
                    .font(.system(size: 17, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            }
            .buttonStyle(PressureButtonStyle(isPrimary: task.runningSince == nil))

            Button("放弃当前行动", action: onEscape)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.noExcuseMuted)
                .padding(.top, 5)
        }
    }

    private var outcomeSection: some View {
        VStack(spacing: 14) {
            TextField("我实际制造了什么？", text: $realityText, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)
                .padding(16)
                .background(Color.noExcusePanel)
                .overlay(
                    Rectangle().stroke(Color.noExcuseBorder, lineWidth: 1)
                )

            Button {
                onMadeReality(realityText)
            } label: {
                Text("我制造了现实")
                    .font(.system(size: 17, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            }
            .buttonStyle(PressureButtonStyle(isPrimary: true))
            .disabled(realityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(realityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)

            Button("我逃跑了", action: onEscape)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.noExcuseRed)
                .padding(.vertical, 8)
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(interval)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct PressureButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isPrimary ? Color.white : Color.noExcuseMuted)
            .background(isPrimary ? Color.noExcuseRed : Color.noExcusePanel)
            .overlay(
                Rectangle().stroke(
                    isPrimary ? Color.noExcuseRed : Color.noExcuseBorder,
                    lineWidth: 1
                )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
