import SwiftUI
import SwiftData

struct LockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [ClaudeAccount]

    @ObservedObject private var crypto = CryptoService.shared
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage: String?
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .shadow(color: .blue.opacity(0.4), radius: 10, y: 4)
                Image(systemName: crypto.hasMasterPassword ? "lock.fill" : "key.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }

            Text(crypto.hasMasterPassword ? "输入主密码以解锁" : "首次使用，请设置主密码")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                SecureField("主密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                if !crypto.hasMasterPassword {
                    SecureField("确认主密码", text: $confirm)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            VStack(spacing: 10) {
                Button(crypto.hasMasterPassword ? "解锁" : "设置并进入") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!crypto.hasMasterPassword && (password.isEmpty || confirm.isEmpty))
                .controlSize(.large)

                if crypto.hasMasterPassword {
                    if crypto.isBiometricUnlockAvailable {
                        Button {
                            unlockWithBiometric()
                        } label: {
                            Label("使用 Touch ID 解锁", systemImage: "touchid")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("忘记主密码？") {
                        showResetConfirm = true
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(48)
        .frame(minWidth: 420, minHeight: 420)
        .confirmationDialog(
            "重置主密码将永久删除所有账号已保存的密码（其他数据保留）。确定继续？",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("重置主密码", role: .destructive) {
                resetMasterPassword()
            }
            Button("取消", role: .cancel) {}
        }
    }

    /// 忘记主密码：清空所有密码密文（旧密文已无法解密），然后删除主密码数据，
    /// 界面自动切换到"设置新主密码"模式，其余账号信息全部保留。
    private func resetMasterPassword() {
        for account in accounts {
            account.passwordCipher = Data()
            account.recoveryPasswordCipher = nil
        }
        try? modelContext.save()
        crypto.resetMasterPassword()
        password = ""
        confirm = ""
        errorMessage = nil
    }

    private func submit() {
        errorMessage = nil
        if crypto.hasMasterPassword {
            do {
                try crypto.unlock(password)
            } catch {
                errorMessage = "主密码错误"
                password = ""
            }
        } else {
            guard !password.isEmpty else {
                errorMessage = "密码不能为空"
                return
            }
            guard password == confirm else {
                errorMessage = "两次输入的密码不一致"
                return
            }
            do {
                try crypto.setupMasterPassword(password)
            } catch {
                errorMessage = "设置失败，请重试"
            }
        }
    }

    private func unlockWithBiometric() {
        errorMessage = nil
        crypto.unlockWithBiometric { result in
            switch result {
            case .success, .cancelled:
                break
            case .failed:
                errorMessage = "验证失败，请重试或使用主密码解锁"
            case .keyMissing:
                errorMessage = "钥匙串中缺少密钥，请先用主密码解锁一次"
            }
        }
    }
}
