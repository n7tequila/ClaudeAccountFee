import Foundation

let moneyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.numberStyle = .currency
    formatter.currencyCode = "CNY"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter
}()

func formatMoney(_ value: Double) -> String {
    moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
