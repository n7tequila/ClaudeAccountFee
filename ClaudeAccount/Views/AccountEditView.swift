import SwiftUI
import SwiftData

struct AccountEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var account: ClaudeAccount
    private let isNewAccount: Bool

    @State private var password: String = ""
    @State private var showPassword = false
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var recoveryEmail: String = ""
    @State private var recoveryPassword: String = ""
    @State private var showRecoveryPassword = false
    @State private var kyc: KYCStatus = .unknown
    @State private var region: String = ""
    @State private var notes: String = ""
    @State private var bannedDate: Date = Date()
    @State private var errorMessage: String?
    @State private var showingAddSubscription = false
    @State private var emailLoginPrompt: EmailLoginPrompt?
    @State private var selectedSubscriptionRecords = Set<PersistentIdentifier>()
    @State private var refreshTick = false
    @State private var didInsert = false

    init(account: ClaudeAccount?) {
        let crypto = CryptoService.shared
        if let account {
            _account = State(initialValue: account)
            isNewAccount = false
            _password = State(initialValue: crypto.decrypt(account.passwordCipher) ?? "")
            _apiKey = State(initialValue: account.apiKeyCipher.flatMap { crypto.decrypt($0) } ?? "")
            _recoveryEmail = State(initialValue: account.recoveryEmail ?? "")
            _recoveryPassword = State(
                initialValue: account.recoveryPasswordCipher.flatMap { crypto.decrypt($0) } ?? ""
            )
            _kyc = State(initialValue: account.kycStatus)
            _region = State(initialValue: account.region ?? "")
            _notes = State(initialValue: account.notes ?? "")
            _bannedDate = State(initialValue: account.bannedDate ?? Date())
        } else {
            _account = State(initialValue: ClaudeAccount(email: "", passwordCipher: Data()))
            isNewAccount = true
        }
    }

    private var sortedSubscriptionRecords: [SubscriptionRecord] {
        _ = refreshTick
        return (account.subscriptions ?? []).sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isNewAccount ? "添加账号" : "编辑账号")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 20)

            Form {
                Section("基本信息") {
                    HStack {
                        TextField("邮箱", text: $account.email)
                            .textContentType(.emailAddress)
                        if !account.email.isEmpty {
                            emailLoginButton(account.email)
                        }
                    }
                    passwordField(title: "密码", text: $password, isVisible: $showPassword)
                    passwordField(title: "API Key（SK）", text: $apiKey, isVisible: $showAPIKey)
                }

                Section("安全邮箱（可选）") {
                    HStack {
                        TextField("安全邮箱", text: $recoveryEmail)
                            .textContentType(.emailAddress)
                        if !recoveryEmail.isEmpty {
                            emailLoginButton(recoveryEmail)
                        }
                    }
                    passwordField(title: "安全邮箱密码", text: $recoveryPassword, isVisible: $showRecoveryPassword)
                }

                Section("当前状态") {
                    LabeledContent("套餐") {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(account.currentPlan.displayColor)
                            Text(account.currentPlan.displayName)
                                .foregroundStyle(account.currentPlan.displayColor)
                        }
                    }
                    LabeledContent("购买日期") {
                        if let date = account.firstSubscriptionDate {
                            Text(formatDate(date))
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("封禁") {
                        Text(account.isBanned ? "已封禁" : "正常")
                            .foregroundStyle(account.isBanned ? .red : .secondary)
                    }
                    if !isNewAccount, account.isBanned {
                        DatePicker("封禁日期", selection: $bannedDate, displayedComponents: .date)
                        Button("解封此账号") {
                            account.isBanned = false
                            account.bannedDate = nil
                            dismiss()
                        }
                        .foregroundStyle(.green)
                    } else if !isNewAccount {
                        Button("标记为已封禁") {
                            account.isBanned = true
                            account.bannedDate = Date()
                            bannedDate = Date()
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section("订阅记录") {
                    if sortedSubscriptionRecords.isEmpty {
                        Text("暂无订阅记录，点击下方“添加订阅”录入每次付费信息")
                            .foregroundStyle(.secondary)
                    } else {
                        subscriptionTable
                    }
                    HStack {
                        Button("添加订阅") {
                            showingAddSubscription = true
                        }
                        Button("删除所选", role: .destructive) {
                            deleteSelectedSubscriptionRecords()
                        }
                        .disabled(selectedSubscriptionRecords.isEmpty)
                    }
                }

                Section("其他") {
                    Picker("KYC", selection: $kyc) {
                        ForEach(KYCStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    TextField("绑定地区（可选）", text: $region)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Spacer()
                Button("取消") {
                    if isNewAccount {
                        modelContext.delete(account)
                    }
                    dismiss()
                }
                Button(isNewAccount ? "创建" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(account.email.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 520, height: 680)
        .onAppear {
            if isNewAccount && !didInsert {
                modelContext.insert(account)
                didInsert = true
            }
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView(account: account) {
                refreshTick.toggle()
            }
        }
        .sheet(item: $emailLoginPrompt) { prompt in
            EmailLoginInputView(prompt: prompt)
        }
    }

    /// 打开邮箱网页登录页；后缀无法识别时弹出输入框让用户录入一次
    private func emailLoginButton(_ email: String) -> some View {
        Button {
            if let url = EmailLoginURL.loginURL(for: email) {
                NSWorkspace.shared.open(url)
            } else {
                emailLoginPrompt = EmailLoginPrompt(email: email)
            }
        } label: {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
        .buttonStyle(.plain)
        .help("打开邮箱登录页")
    }

    private var subscriptionTable: some View {
        Table(sortedSubscriptionRecords, selection: $selectedSubscriptionRecords) {
            TableColumn("套餐") { subscription in
                Text(subscription.plan.displayName)
                    .foregroundStyle(subscription.plan.displayColor)
            }
            .width(max: 60)
            TableColumn("价格") { subscription in
                Text(formatMoney(subscription.price))
            }
            TableColumn("开始") { subscription in
                Text(formatDate(subscription.startDate))
            }
            TableColumn("结束") { subscription in
                Text(formatDate(subscription.endDate))
            }
        }
        .frame(height: 150)
    }

    private func deleteSelectedSubscriptionRecords() {
        for subscription in sortedSubscriptionRecords where selectedSubscriptionRecords.contains(subscription.id) {
            modelContext.delete(subscription)
        }
        selectedSubscriptionRecords.removeAll()
        refreshTick.toggle()
    }

    private func passwordField(title: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack {
            if isVisible.wrappedValue {
                TextField(title, text: text)
            } else {
                SecureField(title, text: text)
            }
            CopyButton(content: text.wrappedValue)
            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let crypto = CryptoService.shared
        // 密码留空表示清除已存密码（空 Data 作为哨兵值，解密时返回 nil）
        let passwordCipher: Data
        if password.isEmpty {
            passwordCipher = Data()
        } else {
            guard let encrypted = crypto.encrypt(password) else {
                errorMessage = "密码加密失败"
                return
            }
            passwordCipher = encrypted
        }
        account.passwordCipher = passwordCipher
        account.apiKeyCipher = apiKey.isEmpty ? nil : crypto.encrypt(apiKey)
        account.recoveryEmail = recoveryEmail.isEmpty ? nil : recoveryEmail
        account.recoveryPasswordCipher = recoveryPassword.isEmpty ? nil : crypto.encrypt(recoveryPassword)
        account.kycStatus = kyc
        account.region = region.isEmpty ? nil : region
        account.notes = notes.isEmpty ? nil : notes
        if account.isBanned {
            account.bannedDate = bannedDate
        }
        try? modelContext.save()
        dismiss()
    }
}

/// 添加一条订阅（付费）记录：套餐 + 价格 + 起止日期
struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: ClaudeAccount
    let onSave: () -> Void

    @State private var plan: PlanTier = .pro
    @State private var price: Double = 0
    @State private var startDate = Date()
    @State private var endDate = Date()

    init(account: ClaudeAccount, onSave: @escaping () -> Void) {
        self.account = account
        self.onSave = onSave
        let calendar = Calendar.current
        let defaultEnd = calendar.date(byAdding: DateComponents(month: 1), to: Date()) ?? Date()
        _endDate = State(initialValue: defaultEnd)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("添加订阅记录")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Picker("套餐", selection: $plan) {
                    ForEach(PlanTier.paidCases) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                TextField("价格（¥）", value: $price, format: .number.precision(.fractionLength(2)))
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(endDate < startDate)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 440, height: 310)
        .onChange(of: startDate) { _, newValue in
            // 默认续费一个自然月，用户仍可手动调整
            endDate = Calendar.current.date(byAdding: DateComponents(month: 1), to: newValue) ?? endDate
        }
    }

    private func save() {
        let subscription = SubscriptionRecord(price: price, startDate: startDate, endDate: endDate, plan: plan)
        subscription.account = account
        modelContext.insert(subscription)
        try? modelContext.save()
        onSave()
        dismiss()
    }
}

struct EmailLoginPrompt: Identifiable {
    let email: String
    var id: String { email }
}

/// 未识别的邮箱后缀：让用户录入一次该邮箱的网页登录地址，之后全局记住
struct EmailLoginInputView: View {
    @Environment(\.dismiss) private var dismiss

    let prompt: EmailLoginPrompt

    @State private var urlString = ""
    @State private var errorMessage: String?

    private var domain: String {
        EmailLoginURL.domain(of: prompt.email) ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("打开邮箱登录页")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Section {
                    Text("未能识别后缀为 **\(domain)** 的邮箱登录地址，请填写该邮箱的网页版登录地址（只需填写一次，之后自动记住）")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("https://", text: $urlString)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Spacer()
                Button("取消") { dismiss() }
                Button("打开并保存") { saveAndOpen() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 460, height: 220)
    }

    private func saveAndOpen() {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        EmailLoginURL.saveCustom(trimmed, for: prompt.email)
        guard let url = EmailLoginURL.loginURL(for: prompt.email) else {
            errorMessage = "地址格式无效，请检查"
            return
        }
        NSWorkspace.shared.open(url)
        dismiss()
    }
}
