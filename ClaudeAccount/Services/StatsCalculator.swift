import Foundation
import SwiftData

struct AccountYearRow: Identifiable {
    let account: ClaudeAccount
    let subscriptionCount: Int
    let yearTotal: Double
    var id: ObjectIdentifier { ObjectIdentifier(account) }
}

struct YearlyReport {
    let year: Int
    let rows: [AccountYearRow]
    let monthly: [Double]
    let total: Double
    let subscriptionCount: Int
    let accountCount: Int
    let activeCount: Int
    let bannedCount: Int
}

enum StatsCalculator {
    private static let calendar = Calendar.current

    /// 年度费用 = 该年内开始的所有订阅记录价格之和（按实际付费日志统计）
    static func report(accounts: [ClaudeAccount], year: Int) -> YearlyReport {
        var rows: [AccountYearRow] = []
        var monthly = Array(repeating: 0.0, count: 12)
        var subscriptionCount = 0

        for account in accounts {
            let subscriptions = (account.subscriptions ?? []).filter {
                calendar.component(.year, from: $0.startDate) == year
            }
            guard !subscriptions.isEmpty else { continue }

            let total = subscriptions.reduce(0) { $0 + $1.price }
            subscriptionCount += subscriptions.count

            for subscription in subscriptions {
                let month = calendar.component(.month, from: subscription.startDate)
                monthly[month - 1] += subscription.price
            }

            rows.append(
                AccountYearRow(
                    account: account,
                    subscriptionCount: subscriptions.count,
                    yearTotal: total
                )
            )
        }

        rows.sort { $0.yearTotal > $1.yearTotal }

        return YearlyReport(
            year: year,
            rows: rows,
            monthly: monthly,
            total: rows.reduce(0) { $0 + $1.yearTotal },
            subscriptionCount: subscriptionCount,
            accountCount: accounts.count,
            activeCount: accounts.filter { !$0.isBanned }.count,
            bannedCount: accounts.filter { $0.isBanned }.count
        )
    }
}
