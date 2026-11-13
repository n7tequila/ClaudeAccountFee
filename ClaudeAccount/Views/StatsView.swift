import SwiftUI
import SwiftData
import Charts
import Pow

struct StatsView: View {
    @Query private var accounts: [ClaudeAccount]
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @AppStorage("statsExcludeBanned") private var excludeBanned = false

    private let calendar = Calendar.current

    private var yearRange: [Int] {
        let current = calendar.component(.year, from: Date())
        return Array((current - 10)...(current + 1)).reversed()
    }

    private var scopedAccounts: [ClaudeAccount] {
        accounts.filter { !(excludeBanned && $0.isBanned) }
    }

    private var report: YearlyReport {
        StatsCalculator.report(accounts: scopedAccounts, year: year)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statCards
                monthlyChart
                detailSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack {
            Picker("年份", selection: $year) {
                ForEach(yearRange, id: \.self) { value in
                    Text("\(value) 年").tag(value)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Toggle("排除已封禁账号", isOn: $excludeBanned)
            Spacer()
        }
    }

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("月度费用")
                .font(.headline)
            Chart {
                ForEach(Array(report.monthly.enumerated()), id: \.offset) { index, value in
                    BarMark(
                        x: .value("月份", "\(index + 1)月"),
                        y: .value("费用", value)
                    )
                    .cornerRadius(5, style: .continuous)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red.opacity(0.9), .orange.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .id(report.year)
            .transition(.movingParts.blur)
            .animation(.easeInOut(duration: 0.3), value: report.year)
            .frame(height: 220)
        }
    }

    @ViewBuilder
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("账号明细")
                .font(.headline)
            if report.rows.isEmpty {
                ContentUnavailableView(
                    "该年份没有订阅记录",
                    systemImage: "chart.bar.xaxis",
                    description: Text("在账号编辑页添加订阅记录后，这里会自动汇总")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Table(report.rows) {
                    TableColumn("账号") { row in
                        Text(row.account.email)
                    }
                    TableColumn("套餐状态") { row in
                        if row.account.isBanned {
                            Text("已封禁")
                                .foregroundStyle(.red)
                        } else {
                            Text(row.account.currentPlan.displayName)
                                .foregroundStyle(row.account.currentPlan.displayColor)
                        }
                    }
                    .width(max: 80)
                    TableColumn("订阅笔数") { row in
                        Text("\(row.subscriptionCount)")
                            .monospacedDigit()
                    }
                    .width(max: 80)
                    TableColumn("年度合计") { row in
                        Text(formatMoney(row.yearTotal))
                            .fontWeight(.semibold)
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }

    private var statCards: some View {
        HStack(spacing: 16) {
            StatCardView(
                title: "年度总费用",
                value: formatMoney(report.total),
                icon: "yensign.circle.fill",
                accent: .red,
                numericValue: report.total
            )
            StatCardView(
                title: "订阅笔数",
                value: "\(report.subscriptionCount)",
                icon: "list.bullet.rectangle.fill",
                accent: .blue,
                numericValue: Double(report.subscriptionCount)
            )
            StatCardView(
                title: "账号 · 活跃 · 封禁",
                value: "\(report.accountCount) · \(report.activeCount) · \(report.bannedCount)",
                icon: "person.2.fill",
                accent: .green,
                numericValue: nil
            )
        }
    }
}

private struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color
    let numericValue: Double?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                if let numericValue {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: numericValue))
                        .animation(.snappy, value: numericValue)
                } else {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}
