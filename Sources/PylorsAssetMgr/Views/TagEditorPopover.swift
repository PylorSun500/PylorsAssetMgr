import SwiftUI

struct TagEditorPopover: View {
    let assetName: String
    let tagKey: String
    let currentValue: String
    let suggestions: [String]

    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var value: String = ""
    @State private var filteredSuggestions: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("编辑标签")
                .font(.headline)

            Text("资产: \(assetName)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("标签键: \(tagKey)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("值:")
                .font(.system(size: 12))

            TextField("输入值...", text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit { onConfirm(value.trimmingCharacters(in: .whitespaces)) }
                .onChange(of: value) { _, newValue in
                    filterSuggestions(newValue)
                }

            // 建议列表
            if !filteredSuggestions.isEmpty {
                List(filteredSuggestions, id: \.self) { s in
                    Text(s)
                        .font(.system(size: 11))
                        .onTapGesture { value = s }
                }
                .frame(height: 120)
                .listStyle(.plain)
            }

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("确定") { onConfirm(value.trimmingCharacters(in: .whitespaces)) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            value = currentValue
            filterSuggestions("")
        }
    }

    private func filterSuggestions(_ query: String) {
        if query.isEmpty {
            filteredSuggestions = suggestions
        } else {
            filteredSuggestions = suggestions.filter {
                $0.lowercased().contains(query.lowercased())
            }
        }
    }
}
