import SwiftUI

extension PlanTier {
    var displayColor: Color {
        switch self {
        case .free: return .secondary
        case .pro: return .blue
        case .max: return .purple
        case .ultra: return .orange
        }
    }
}
