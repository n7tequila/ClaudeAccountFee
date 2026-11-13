import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [ClaudeAccount]

    let planFilter: AccountPlanFilter

    @State private var searchText = ""
    @State private var selected = Set<PersistentIdentifier>()
    @State private var editing: ClaudeAccount?
    @State private var showingNew = false
    @State private var subscriptionTarget: ClaudeAccount?
    @State private var pendingDelete: Set<PersistentIdentifier> = []
    @State private var showDeleteConfirm = false
    @AppStorage("hideBannedAccounts") private var hideBanned = false

    var filtered: [ClaudeAccount] {
        accounts
            .filter(matchesFilter)
            .sorted { ($0.firstSubscriptionDate ?? .distantPast) > ($1.firstSubscriptionDate ?? .distantPast) }
    }

    private func matchesFilter(_ account: ClaudeAccount) -> Bool {
        if hideBanned && account.isBanned { return false }
        if !matchesPlanFilter(account) { return false }
        if !matchesSearch(account) { return false }
        return true
    }

    private func matchesPlanFilter(_ account: ClaudeAccount) -> Bool {
        switch planFilter {
        case .all:
            return true
        case .banned:
            return account.isBanned
        case .free, .pro, .max, .ultra:
            guard let tier = planFilter.planTier else { return false }
            return !account.isBanned && account.currentPlan == tier
        }
    }

    private func matchesSearch(_ account: ClaudeAccount) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        let haystack = [account.email, account.region ?? ""]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(query)
    }

    private var accountTable: some View {
        Table(filtered, selection: $selected) {
            TableColumn("邮箱", value: \.email)
            TableColumn("KYC") { account in
                Text(account.kycStatus.displayName)
            }
            .width(max: 60)
            TableColumn("地区") { account in
                Text(account.region ?? "—")
            }
            .width(max: 100)
            TableColumn("状态") { account in
                if account.isBanned {
                    Label("已封禁", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .labelStyle(.titleAndIcon)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(account.currentPlan.displayColor)
                        Text(account.currentPlan.displayName)
                    }
                }
            }
            .width(max: 90)
            TableColumn("订阅到期") { account in
                if let end = account.latestSubscriptionEnd {
                    Text(formatDate(end))
                        .foregroundStyle(end < Date() ? .red : .primary)
                } else {
                    Text("—")
                }
            }
            TableColumn("购买日期") { account in
                if let date = account.firstSubscriptionDate {
                    Text(formatDate(date))
                } else {
                    Text("—")
                }
            }
            TableColumn("封禁日期") { account in
                if let bannedDate = account.bannedDate {
                    Text(formatDate(bannedDate))
                } else {
                    Text("—")
                }
            }
        }
    }

    var body: some View {
        accountTable
        .searchable(text: $searchText, placement: .toolbar)
        .overlay(emptyStateOverlay)
        .contextMenu(
            forSelectionType: ClaudeAccount.ID.self,
            menu: { ids in
                Button("编辑") {
                    openEditor(for: ids)
                }
                Button("添加订阅记录") {
                    subscriptionTarget = account(for: ids)
                }
                if let account = account(for: ids) {
                    Button(account.isBanned ? "解除封禁" : "封禁", role: account.isBanned ? nil : .destructive) {
                        toggleBan(account)
                    }
                }
                Divider()
                Button("删除", role: .destructive) {
                    pendingDelete = ids
                    showDeleteConfirm = true
                }
            },
            primaryAction: { ids in
                openEditor(for: ids)
            }
        )
        .toolbar { toolbarContent }
        .sheet(item: $editing) { account in
            AccountEditView(account: account)
        }
        .sheet(isPresented: $showingNew) {
            AccountEditView(account: nil)
        }
        .sheet(item: $subscriptionTarget) { account in
            AddSubscriptionView(account: account, onSave: {})
        }
        .confirmationDialog(
            "确定删除选中的 \(pendingDelete.count) 个账号？此操作不可撤销。",
            isPresented: $showDeleteConfirm
        ) {
            Button("删除", role: .destructive) {
                deleteAccounts(pendingDelete)
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if filtered.isEmpty {
            ContentUnavailableView(
                accounts.isEmpty ? "还没有账号" : "没有匹配的账号",
                systemImage: "person.2.slash",
                description: Text(accounts.isEmpty ? "点击工具栏的 + 添加第一个 Claude 账号" : "试试调整搜索或侧栏筛选")
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showingNew = true
            } label: {
                Label("新增账号", systemImage: "plus")
            }
            Button {
                exportAccounts()
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .help("导出为 JSON（不含密码）")
        }
        ToolbarItemGroup {
            Toggle("隐藏已封禁", isOn: $hideBanned)
                .toggleStyle(.checkbox)
        }
    }

    private func openEditor(for ids: Set<PersistentIdentifier>) {
        if let first = ids.first {
            editing = accounts.first { $0.id == first }
        }
    }

    private func account(for ids: Set<PersistentIdentifier>) -> ClaudeAccount? {
        guard let first = ids.first else { return nil }
        return accounts.first { $0.id == first }
    }

    private func toggleBan(_ account: ClaudeAccount) {
        if account.isBanned {
            account.isBanned = false
            account.bannedDate = nil
        } else {
            account.isBanned = true
            account.bannedDate = Date()
        }
    }

    private func deleteAccounts(_ ids: Set<PersistentIdentifier>) {
        for account in accounts where ids.contains(account.id) {
            modelContext.delete(account)
        }
        selected.subtract(ids)
    }

    private func exportAccounts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-accounts.json"
        panel.title = "导出账号数据（不包含密码）"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let payload = filtered.map(AccountExport.init(account:))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(payload).write(to: url)
        } catch {
            // 写盘失败时静默忽略，用户可重试
        }
    }
}

private struct AccountExport: Codable {
    var email: String
    var recoveryEmail: String?
    var purchaseDate: Date?
    var isBanned: Bool
    var bannedDate: Date?
    var kyc: String
    var region: String?
    var notes: String?
    var currentPlan: String
    var subscriptionCount: Int
    var totalSpent: Double

    init(account: ClaudeAccount) {
        self.email = account.email
        self.recoveryEmail = account.recoveryEmail
        self.purchaseDate = account.firstSubscriptionDate
        self.isBanned = account.isBanned
        self.bannedDate = account.bannedDate
        self.kyc = account.kycStatus.rawValue
        self.region = account.region
        self.notes = account.notes
        self.currentPlan = account.currentPlan.rawValue
        self.subscriptionCount = account.subscriptions?.count ?? 0
        self.totalSpent = (account.subscriptions ?? []).reduce(0) { $0 + $1.price }
    }
}
