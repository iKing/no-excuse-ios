import SwiftUI

struct EmptyTaskView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 10) {
                Text("00:00")
                    .font(.system(size: 76, weight: .black, design: .monospaced))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.white.opacity(0.16))

                Text("没有行动，就没有现实。")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.noExcuseMuted)
            }
            .padding(.vertical, 32)

            Button(action: onCreate) {
                Text("锁定一个行动")
                    .font(.system(size: 17, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            }
            .buttonStyle(PressureButtonStyle(isPrimary: true))
        }
    }
}
