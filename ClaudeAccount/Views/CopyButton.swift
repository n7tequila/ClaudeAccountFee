import SwiftUI

/// 复制到剪贴板的小按钮，复制成功后短暂显示对勾
struct CopyButton: View {
    let content: String

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? .green : .secondary)
                .frame(width: 16)
        }
        .buttonStyle(.plain)
        .disabled(content.isEmpty)
        .help(copied ? "已复制" : "复制到剪贴板")
    }
}
