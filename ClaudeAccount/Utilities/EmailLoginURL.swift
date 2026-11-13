import Foundation

/// 根据邮箱后缀解析网页版邮箱登录地址。
/// 内置常见服务商映射；未知后缀支持用户手动录入一次并永久记住。
enum EmailLoginURL {
    private static let customKey = "emailLoginURLMap"

    private static let known: [String: String] = [
        "gmail.com": "https://mail.google.com",
        "googlemail.com": "https://mail.google.com",
        "qq.com": "https://mail.qq.com",
        "foxmail.com": "https://mail.qq.com",
        "163.com": "https://mail.163.com",
        "126.com": "https://mail.126.com",
        "yeah.net": "https://mail.yeah.net",
        "sina.com": "https://mail.sina.com.cn",
        "sina.cn": "https://mail.sina.com.cn",
        "sohu.com": "https://mail.sohu.com",
        "yahoo.com": "https://mail.yahoo.com",
        "yahoo.com.cn": "https://mail.yahoo.com",
        "yahoo.com.tw": "https://mail.yahoo.com",
        "outlook.com": "https://outlook.live.com/mail",
        "hotmail.com": "https://outlook.live.com/mail",
        "live.com": "https://outlook.live.com/mail",
        "msn.com": "https://outlook.live.com/mail",
        "icloud.com": "https://www.icloud.com/mail",
        "me.com": "https://www.icloud.com/mail",
        "mac.com": "https://www.icloud.com/mail",
        "proton.me": "https://account.proton.me/login",
        "protonmail.com": "https://account.proton.me/login",
        "pm.me": "https://account.proton.me/login",
        "139.com": "https://mail.139.com",
        "aliyun.com": "https://mail.aliyun.com",
        "263.net": "https://www.263.net",
        "mail.ru": "https://mail.ru",
        "yandex.com": "https://mail.yandex.com",
        "yandex.ru": "https://mail.yandex.ru",
        "aol.com": "https://mail.aol.com",
        "zoho.com": "https://mail.zoho.com",
        "gmx.com": "https://www.gmx.com",
        "gmx.net": "https://www.gmx.net",
        "fastmail.com": "https://www.fastmail.com/login",
        "tutanota.com": "https://mail.tutanota.com",
        "tuta.io": "https://mail.tutanota.com"
    ]

    static func domain(of email: String) -> String? {
        guard let at = email.lastIndex(of: "@") else { return nil }
        let domain = email[email.index(after: at)...].lowercased().trimmingCharacters(in: .whitespaces)
        return domain.isEmpty ? nil : domain
    }

    private static var customMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: customKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: customKey) }
    }

    /// 已知映射或用户录入过的地址；都无法解析时返回 nil
    static func loginURL(for email: String) -> URL? {
        guard let domain = domain(of: email) else { return nil }
        guard let path = known[domain] ?? customMap[domain] else { return nil }
        return URL(string: path)
    }

    /// 用户手动录入某个后缀的登录地址（只需一次，全局生效）
    static func saveCustom(_ rawURL: String, for email: String) {
        guard let domain = domain(of: email) else { return }
        var value = rawURL.trimmingCharacters(in: .whitespaces)
        if !value.lowercased().hasPrefix("http://"), !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }
        var map = customMap
        map[domain] = value
        customMap = map
    }
}
