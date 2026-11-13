import SwiftUI
import KeyboardShortcuts

enum AccountPlanFilter: String, CaseIterable, Identifiable {
    case all
    case free
    case pro
    case max
    case ultra
    case banned

    var id: Self { self }

    var displayName: String {
        switch self {
        case .all: return "全部账号"
        case .free: return "Free"
        case .pro: return "Pro"
        case .max: return "Max"
        case .ultra: return "Ultra"
        case .banned: return "已封禁"
        }
    }

    var icon: String {
        switch self {
        case .all: return "person.2.fill"
        case .free: return "circle"
        case .pro: return "circle.fill"
        case .max: return "diamond.fill"
        case .ultra: return "crown.fill"
        case .banned: return "xmark.octagon.fill"
        }
    }

    var planTier: PlanTier? { PlanTier(rawValue: rawValue) }

    static let sidebarCases: [AccountPlanFilter] = [.all, .free, .pro, .max, .ultra, .banned]
}

enum SidebarItem: Hashable {
    case accounts(AccountPlanFilter)
    case stats
}

extension KeyboardShortcuts.Name {
    /// 全局锁定快捷键：⌘⇧⌥L
    nonisolated(unsafe) static let lockApp = Self("lockApp", default: .init(.l, modifiers: [.command, .shift, .option]))
}

struct ContentView: View {
    @ObservedObject private var crypto = CryptoService.shared
    @State private var selection: SidebarItem = .accounts(.all)
    @State private var selectedAccount: ClaudeAccount?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 240)
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    crypto.lock()
                } label: {
                    Label("锁定", systemImage: "lock.fill")
                }
            }
        }
        .onAppear {
            KeyboardShortcuts.onKeyDown(for: .lockApp) {
                crypto.lock()
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch selection {
        case .accounts(let filter):
            AccountListView(planFilter: filter, selectedAccount: $selectedAccount)
                .navigationSplitViewColumnWidth(min: 360, ideal: 440, max: 560)
        case .stats:
            StatsView()
                .navigationSplitViewColumnWidth(min: 480, ideal: 680)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .accounts:
            if let account = selectedAccount {
                AccountDetailView(account: account)
                    .id(account.id)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420)
            } else {
                ContentUnavailableView(
                    "未选择账号",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("在左侧列表中选择一个账号查看详情")
                )
                .navigationSplitViewColumnWidth(min: 320, ideal: 420)
            }
        case .stats:
            // 统计页占满宽度，隐藏详情栏
            Color.clear
                .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
        }
    }
}
