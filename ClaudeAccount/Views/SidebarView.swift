import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Query private var accounts: [ClaudeAccount]

    private func count(for filter: AccountPlanFilter) -> Int {
        switch filter {
        case .all:
            return accounts.count
        case .banned:
            return accounts.filter(\.isBanned).count
        case .free, .pro, .max, .ultra:
            guard let tier = filter.planTier else { return 0 }
            return accounts.filter { !$0.isBanned && $0.currentPlan == tier }.count
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("概览") {
                Label("账号", systemImage: "person.2.fill")
                    .tag(SidebarItem.accounts(.all))
                Label("年度统计", systemImage: "chart.bar.fill")
                    .tag(SidebarItem.stats)
            }

            Section("按套餐筛选") {
                ForEach(AccountPlanFilter.sidebarCases) { filter in
                    HStack {
                        Label(filter.displayName, systemImage: filter.icon)
                            .foregroundStyle(filter == .banned ? .red : .primary)
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        Text("\(count(for: filter))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .tag(SidebarItem.accounts(filter))
                }
            }
        }
        .listStyle(.sidebar)
    }
}
