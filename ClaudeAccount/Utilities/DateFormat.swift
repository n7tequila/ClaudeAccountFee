import Foundation

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

func formatDate(_ date: Date) -> String {
    dayFormatter.string(from: date)
}
