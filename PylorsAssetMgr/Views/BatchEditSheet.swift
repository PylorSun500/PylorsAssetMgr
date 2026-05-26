import SwiftUI

struct BatchEditSheet: View {
    let assetCount: Int
    let onConfirm: (String, String) -> Void
    let onCancel: () -> Void

    @State private var key: String = ""
    @State private var value: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("批量编辑标签")
                .font(.headline)

            Text("为 \(assetCount) 个资产设置标签:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("标签键:")
                    .font(.system(size: 12))

                TextField("输入键名...", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("标签值:")
                    .font(.system(size: 12))

                TextField("输入值...", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("确定") {
                    let k = key.trimmingCharacters(in: .whitespaces)
                    let v = value.trimmingCharacters(in: .whitespaces)
                    if !k.isEmpty {
                        onConfirm(k, v)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 360, height: 220)
    }
}
