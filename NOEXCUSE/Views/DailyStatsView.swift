import SwiftUI

struct DailyStatsView: View {
    let stats: DailyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今天制造了什么不可逆现实？")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 1) {
                statCell(value: stats.madeRealityCount, label: "有效行动")
                statCell(value: stats.escapedCount, label: "逃跑")
                statCell(value: stats.actionScore, label: "行动值")
            }
            .background(Color.noExcuseBorder)
            .overlay(Rectangle().stroke(Color.noExcuseBorder, lineWidth: 1))

            if stats.realityRecords.isEmpty {
                Text("还没有。空白不会替你变成现实。")
                    .font(.footnote)
                    .foregroundStyle(Color.noExcuseMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(stats.realityRecords, id: \.id) { record in
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(Color.noExcuseRed)
                                .frame(width: 3, height: 36)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.realityText ?? "")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(record.resolvedAt?.formatted(date: .omitted, time: .shortened) ?? "")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Color.noExcuseMuted)
                            }
                        }
                        .padding(.vertical, 13)

                        if record.id != stats.realityRecords.last?.id {
                            Divider().overlay(Color.noExcuseBorder)
                        }
                    }
                }
            }
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 25, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.noExcuseMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.noExcusePanel)
    }
}

struct HistoryView: View {
    let records: [ActionTask]
    let onDelete: (ActionTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recordToDelete: ActionTask?

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "没有历史",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("制造现实，或者承认逃跑。这里不记录想法。")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.records, id: \.id) { record in
                                    historyRow(record)
                                        .listRowBackground(Color.noExcusePanel)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.noExcuseBlack.ignoresSafeArea())
            .navigationTitle("行动历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            "删除后无法恢复。",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("永久删除", role: .destructive) {
                guard let recordToDelete else { return }
                onDelete(recordToDelete)
                self.recordToDelete = nil
            }
            Button("取消", role: .cancel) { recordToDelete = nil }
        }
    }

    private func historyRow(_ record: ActionTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(record.outcome == .madeReality ? Color.noExcuseRed : Color.noExcuseMuted)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(record.outcome == .madeReality ? "制造了现实  +10" : "逃跑  +0")
                        .font(.caption.weight(.black))
                        .foregroundStyle(
                            record.outcome == .madeReality
                                ? Color.noExcuseRed
                                : Color.noExcuseMuted
                        )

                    Spacer()

                    Text(record.resolvedAt?.formatted(date: .omitted, time: .shortened) ?? "")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.noExcuseMuted)
                }

                Text(record.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                if let realityText = record.realityText, !realityText.isEmpty {
                    Text(realityText)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }

            Button {
                recordToDelete = record
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.noExcuseMuted)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除这条历史")
        }
        .padding(.vertical, 8)
    }

    private var sections: [HistorySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.resolvedAt ?? .distantPast)
        }

        return grouped.keys.sorted(by: >).map { date in
            HistorySection(
                date: date,
                title: date.formatted(.dateTime.year().month().day().weekday()),
                records: grouped[date, default: []]
            )
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { recordToDelete != nil },
            set: { if !$0 { recordToDelete = nil } }
        )
    }
}

private struct HistorySection: Identifiable {
    let date: Date
    let title: String
    let records: [ActionTask]

    var id: Date { date }
}
