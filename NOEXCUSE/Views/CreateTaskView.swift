import SwiftUI

struct CreateTaskView: View {
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var title = ""

    var body: some View {
        ZStack {
            Color.noExcuseBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("锁定唯一行动")
                        .font(.system(size: 23, weight: .black, design: .rounded))
                    Spacer()
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.noExcuseMuted)
                }

                TextField("你现在要让什么接触现实？", text: $title, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(2...3)
                    .submitLabel(.done)
                    .padding(16)
                    .background(Color.noExcusePanel)
                    .overlay(Rectangle().stroke(Color.noExcuseBorder, lineWidth: 1))
                    .onSubmit(create)

                Button(action: create) {
                    Text("锁定并开始")
                        .font(.system(size: 17, weight: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                }
                .buttonStyle(PressureButtonStyle(isPrimary: true))
                .disabled(trimmedTitle.isEmpty)
                .opacity(trimmedTitle.isEmpty ? 0.4 : 1)

                Spacer()
            }
            .padding(22)
        }
        .onAppear { isFocused = true }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() {
        guard !trimmedTitle.isEmpty else { return }
        onCreate(trimmedTitle)
    }
}
