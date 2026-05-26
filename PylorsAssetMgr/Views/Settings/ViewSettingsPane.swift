import SwiftUI

struct ViewSettingsPane: View {
    @State private var treeMode: DirectoryTreeMode = AppSettings.shared.directoryTreeMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("视图")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("目录树展示模式")
                        .font(.system(size: 13, weight: .medium))

                    Picker("", selection: $treeMode) {
                        ForEach(DirectoryTreeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: treeMode) { _, newMode in
                        AppSettings.shared.directoryTreeMode = newMode
                    }

                    Text(treeMode == .fullFileTree
                         ? "侧边栏中完整显示所有目录和文件。"
                         : "侧边栏仅显示目录结构，每个目录下方提示文件数量。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Text("视图设置为全局偏好，作用于所有工作区。")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
