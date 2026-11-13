import SwiftUI

/// 复制到剪贴板的小按钮，复制成功后短暂显示对勾。
/// 出于安全考虑，密码明文会在 60 秒后自动从剪贴板清除
/// （仅当用户没有复制其他内容时才清除，避免误删）。
struct CopyButton: View {
    let content: String

    @State private var copied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            let changeCount = pasteboard.changeCount
            // 60 秒后自动清除剪贴板中的敏感内容
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                if NSPasteboard.general.changeCount == changeCount {
                    NSPasteboard.general.clearContents()
                }
            }
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
        .help(copied ? "已复制（60 秒后自动清除剪贴板）" : "复制到剪贴板")
    }
}
