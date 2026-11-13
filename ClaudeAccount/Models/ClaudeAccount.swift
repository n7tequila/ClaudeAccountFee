import Foundation
import SwiftData

enum KYCStatus: String, Codable, CaseIterable, Identifiable {
    case unknown
    case yes
    case no

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yes: return "是"
        case .no: return "否"
        case .unknown: return "未知"
        }
    }
}

enum PlanTier: String, Codable, CaseIterable, Identifiable {
    case free
    case pro
    case max
    case ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .max: return "Max"
        case .ultra: return "Ultra"
        }
    }

    /// 付费套餐（Free 无需付费记录）
    static let paidCases: [PlanTier] = [.pro, .max, .ultra]
}

@Model
final class ClaudeAccount {
    var email: String
    var passwordCipher: Data
    var apiKeyCipher: Data?
    var recoveryEmail: String?
    var recoveryPasswordCipher: Data?
    var isBanned: Bool
    var bannedDate: Date?
    var kycRaw: String
    var region: String?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SubscriptionRecord.account)
    var subscriptions: [SubscriptionRecord]?

    var kycStatus: KYCStatus {
        get { KYCStatus(rawValue: kycRaw) ?? .unknown }
        set { kycRaw = newValue.rawValue }
    }

    /// 空 Data 表示未保存密码（例如主密码重置后）
    var hasStoredPassword: Bool { !passwordCipher.isEmpty }

    /// 当前套餐状态：由未过期的订阅记录自动推导，全部过期则为 Free
    var currentPlan: PlanTier {
        let today = Calendar.current.startOfDay(for: Date())
        guard let active = subscriptions?.filter({ $0.endDate >= today }), !active.isEmpty,
              let latest = active.max(by: { $0.endDate < $1.endDate }) else {
            return .free
        }
        return latest.plan
    }

    /// 最近一次订阅的结束日期
    var latestSubscriptionEnd: Date? {
        subscriptions?.map(\.endDate).max()
    }

    /// 购买日期：由订阅记录推导（最早一条的开始日期），无记录则为 nil
    var firstSubscriptionDate: Date? {
        subscriptions?.map(\.startDate).min()
    }

    init(
        email: String,
        passwordCipher: Data,
        apiKeyCipher: Data? = nil,
        recoveryEmail: String? = nil,
        recoveryPasswordCipher: Data? = nil,
        isBanned: Bool = false,
        bannedDate: Date? = nil,
        kycStatus: KYCStatus = .unknown,
        region: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.email = email
        self.passwordCipher = passwordCipher
        self.apiKeyCipher = apiKeyCipher
        self.recoveryEmail = recoveryEmail
        self.recoveryPasswordCipher = recoveryPasswordCipher
        self.isBanned = isBanned
        self.bannedDate = bannedDate
        self.kycRaw = kycStatus.rawValue
        self.region = region
        self.notes = notes
        self.createdAt = createdAt
        self.subscriptions = []
    }
}
