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
