import Foundation
import SwiftData

@Model
final class SubscriptionRecord {
    var price: Double
    var startDate: Date
    var endDate: Date
    var planRaw: String
    var account: ClaudeAccount?

    var plan: PlanTier {
        get { PlanTier(rawValue: planRaw) ?? .pro }
        set { planRaw = newValue.rawValue }
    }

    init(price: Double, startDate: Date = Date(), endDate: Date, plan: PlanTier = .pro) {
        self.price = price
        self.startDate = startDate
        self.endDate = endDate
        self.planRaw = plan.rawValue
    }
}
