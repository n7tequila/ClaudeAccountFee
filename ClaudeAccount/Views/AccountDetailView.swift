import SwiftUI
import SwiftData

/// 账号详情面板：1Password 式布局 —— 左侧固定宽度字段名列，值左对齐紧随其后，
/// 字号偏大、留白充足、发丝分割线
struct AccountDetailView: View {
    let account: ClaudeAccount

    @State private var editing = false
    @State private var showingAddSubscription = false
    @State private var showPassword = false
    @State private var showAPIKey = false
    @State private var showRecoveryPassword = false

    private var crypto: CryptoService { CryptoService.shared }

    private var password: String { crypto.decrypt(account.passwordCipher) ?? "" }
    private var apiKey: String { account.apiKeyCipher.flatMap { crypto.decrypt($0) } ?? "" }
    private var recoveryPassword: String { account.recoveryPasswordCipher.flatMap { crypto.decrypt($0) } ?? "" }

    private var subscriptions: [SubscriptionRecord] {
        (account.subscriptions ?? []).sorted { $0.startDate > $1.startDate }
    }

    private var totalSpent: Double {
        (account.subscriptions ?? []).reduce(0) { $0 + $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                section("凭据") {
                    secretRow(title: "密码", value: password, isVisible: $showPassword)
                    hairline
                    secretRow(title: "API Key（SK）", value: apiKey, isVisible: $showAPIKey)
                    hairline
                    fieldRow("安全邮箱") {
                        if let email = account.recoveryEmail {
                            Text(email)
                                .textSelection(.enabled)
                            Spacer()
                            emailLoginButton(email)
                        } else {
                            placeholder("未设置")
                        }
                    }
                    hairline
                    secretRow(title: "安全邮箱密码", value: recoveryPassword, isVisible: $showRecoveryPassword)
                }
                section("当前状态") {
                    fieldRow("套餐") {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(account.currentPlan.displayColor)
                            Text(account.currentPlan.displayName)
                                .foregroundStyle(account.currentPlan.displayColor)
                        }
                    }
                    hairline
                    fieldRow("购买日期") {
                        if let date = account.firstSubscriptionDate {
                            Text(formatDate(date))
                        } else {
                            placeholder("—")
                        }
                    }
                    hairline
                    fieldRow("封禁") {
                        if account.isBanned {
                            if let date = account.bannedDate {
                                Text("已封禁 · \(formatDate(date))")
                                    .foregroundStyle(.red)
                            } else {
                                Text("已封禁").foregroundStyle(.red)
                            }
                        } else {
                            placeholder("正常")
                        }
                    }
                    hairline
                    fieldRow("KYC") {
                        Text(account.kycStatus.displayName)
                    }
                    if let region = account.region, !region.isEmpty {
                        hairline
                        fieldRow("绑定地区") { Text(region) }
                    }
                    if let notes = account.notes, !notes.isEmpty {
                        hairline
                        fieldRow("备注") {
                            Text(notes).textSelection(.enabled)
                        }
                    }
                }
                section("订阅记录") {
                    if subscriptions.isEmpty {
                        Text("暂无订阅记录")
                            .font(valueFont)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Table(subscriptions) {
                                TableColumn("套餐") { subscription in
                                    Text(subscription.plan.displayName)
                                        .font(valueFont)
                                        .foregroundStyle(subscription.plan.displayColor)
                                }
                                .width(max: 55)
                                TableColumn("价格") { subscription in
                                    Text(formatMoney(subscription.price)).font(valueFont)
                                }
                                TableColumn("开始") { subscription in
                                    Text(formatDate(subscription.startDate)).font(valueFont)
                                }
                                TableColumn("结束") { subscription in
                                    Text(formatDate(subscription.endDate))
                                        .font(valueFont)
                                        .foregroundStyle(subscription.endDate < Date() ? .red : .primary)
                                }
                            }
                            .frame(height: min(220, max(90, CGFloat(subscriptions.count) * 28 + 34)))
                            HStack {
                                Text("共 \(subscriptions.count) 条 · 累计 \(formatMoney(totalSpent))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("添加订阅") {
                                    showingAddSubscription = true
                                }
                                .font(.system(size: 13))
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $editing) {
            AccountEditView(account: account)
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView(account: account, onSave: {})
        }
    }

    private var valueFont: Font { .system(size: 15) }
    private var labelWidth: CGFloat { 110 }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(account.email)
                .font(.system(size: 22, weight: .semibold))
                .textSelection(.enabled)
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(account.currentPlan.displayColor)
                    Text(account.currentPlan.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(account.currentPlan.displayColor.opacity(0.12), in: Capsule())
                .foregroundStyle(account.currentPlan.displayColor)

                if account.isBanned {
                    Text("已封禁")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.12), in: Capsule())
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("编辑…") {
                    editing = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
        }
    }

    /// 字段行：左侧固定宽度标签列，值紧随其后；操作图标统一靠右
    private func fieldRow<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func secretRow(title: String, value: String, isVisible: Binding<Bool>) -> some View {
        fieldRow(title) {
            Group {
                if value.isEmpty {
                    placeholder("未设置")
                } else if isVisible.wrappedValue {
                    Text(value)
                        .textSelection(.enabled)
                        .lineLimit(1)
                } else {
                    Text(String(repeating: "•", count: min(max(value.count, 8), 24)))
                        .foregroundStyle(.secondary)
                }
            }
            .font(valueFont)

            Spacer()

            CopyButton(content: value)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(value.isEmpty)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private var hairline: some View {
        Divider()
            .overlay(Color(nsColor: .separatorColor).opacity(0.4))
    }

    /// 打开邮箱网页登录页；后缀无法识别时提示去编辑页录入
    private func emailLoginButton(_ email: String) -> some View {
        Button {
            if let url = EmailLoginURL.loginURL(for: email) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Image(systemName: "envelope.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
        .buttonStyle(.plain)
        .help(EmailLoginURL.loginURL(for: email) == nil ? "未知后缀，请在编辑页录入登录地址" : "打开邮箱登录页")
        .disabled(EmailLoginURL.loginURL(for: email) == nil)
    }
}
