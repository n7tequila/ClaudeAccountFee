import SwiftUI
import SwiftData

/// 账号详情面板：展示选中账号的完整信息，无需打开编辑弹窗即可查看/复制
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
            VStack(alignment: .leading, spacing: 20) {
                header
                section("凭据") {
                    secretRow(title: "密码", value: password, isVisible: $showPassword)
                    Divider()
                    secretRow(title: "API Key（SK）", value: apiKey, isVisible: $showAPIKey)
                    Divider()
                    LabeledContent("安全邮箱") {
                        HStack(spacing: 8) {
                            if let email = account.recoveryEmail {
                                Text(email).textSelection(.enabled)
                                emailLoginButton(email)
                            } else {
                                Text("未设置").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                    secretRow(title: "安全邮箱密码", value: recoveryPassword, isVisible: $showRecoveryPassword)
                }
                section("当前状态") {
                    LabeledContent("套餐") {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(account.currentPlan.displayColor)
                            Text(account.currentPlan.displayName)
                                .foregroundStyle(account.currentPlan.displayColor)
                        }
                    }
                    Divider()
                    LabeledContent("购买日期") {
                        if let date = account.firstSubscriptionDate {
                            Text(formatDate(date))
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    LabeledContent("封禁") {
                        if account.isBanned {
                            if let date = account.bannedDate {
                                Text("已封禁 · \(formatDate(date))").foregroundStyle(.red)
                            } else {
                                Text("已封禁").foregroundStyle(.red)
                            }
                        } else {
                            Text("正常").foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    LabeledContent("KYC") {
                        Text(account.kycStatus.displayName)
                    }
                    if let region = account.region, !region.isEmpty {
                        Divider()
                        LabeledContent("绑定地区") { Text(region) }
                    }
                    if let notes = account.notes, !notes.isEmpty {
                        Divider()
                        LabeledContent("备注") {
                            Text(notes).textSelection(.enabled)
                        }
                    }
                }
                section("订阅记录") {
                    if subscriptions.isEmpty {
                        Text("暂无订阅记录")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Table(subscriptions) {
                                TableColumn("套餐") { subscription in
                                    Text(subscription.plan.displayName)
                                        .foregroundStyle(subscription.plan.displayColor)
                                }
                                .width(max: 55)
                                TableColumn("价格") { subscription in
                                    Text(formatMoney(subscription.price))
                                }
                                TableColumn("开始") { subscription in
                                    Text(formatDate(subscription.startDate))
                                }
                                TableColumn("结束") { subscription in
                                    Text(formatDate(subscription.endDate))
                                        .foregroundStyle(subscription.endDate < Date() ? .red : .primary)
                                }
                            }
                            .frame(height: min(200, max(80, CGFloat(subscriptions.count) * 26 + 30)))
                            HStack {
                                Text("共 \(subscriptions.count) 条 · 累计 \(formatMoney(totalSpent))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("添加订阅") {
                                    showingAddSubscription = true
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $editing) {
            AccountEditView(account: account)
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView(account: account, onSave: {})
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.email)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(account.currentPlan.displayColor)
                        Text(account.currentPlan.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(account.currentPlan.displayColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(account.currentPlan.displayColor)

                    if account.isBanned {
                        Text("已封禁")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer()
            Button("编辑…") {
                editing = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    private func secretRow(title: String, value: String, isVisible: Binding<Bool>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                if value.isEmpty {
                    Text("未设置").foregroundStyle(.secondary)
                } else if isVisible.wrappedValue {
                    Text(value)
                        .textSelection(.enabled)
                        .lineLimit(1)
                } else {
                    Text(String(repeating: "•", count: min(max(value.count, 8), 24)))
                        .foregroundStyle(.secondary)
                }
                CopyButton(content: value)
                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(value.isEmpty)
            }
        }
    }

    /// 打开邮箱网页登录页；后缀无法识别时暂不支持录入（请在编辑页操作）
    private func emailLoginButton(_ email: String) -> some View {
        Button {
            if let url = EmailLoginURL.loginURL(for: email) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
        .buttonStyle(.plain)
        .help(EmailLoginURL.loginURL(for: email) == nil ? "未知后缀，请在编辑页录入登录地址" : "打开邮箱登录页")
        .disabled(EmailLoginURL.loginURL(for: email) == nil)
    }
}
