import Foundation
import CryptoKit
import Combine
import LocalAuthentication
import Security

final class CryptoService: ObservableObject, @unchecked Sendable {
    static let shared = CryptoService()

    @Published private(set) var isUnlocked = false

    private let saltKey = "com.claudeaccount.masterSalt"
    private let verifierKey = "com.claudeaccount.masterVerifier"
    private let iterations = 310_000
    private var key: SymmetricKey?

    var hasMasterPassword: Bool {
        UserDefaults.standard.data(forKey: saltKey) != nil
    }

    private init() {}

    func setupMasterPassword(_ password: String) throws {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        let salt = Data(bytes)
        let derived = try deriveKey(password: password, salt: salt)
        let verifier = verifierData(from: derived)
        UserDefaults.standard.set(salt, forKey: saltKey)
        UserDefaults.standard.set(verifier, forKey: verifierKey)
        key = derived
        isUnlocked = true
        storeKeyInKeychain(derived)
    }

    func unlock(_ password: String) throws {
        guard let salt = UserDefaults.standard.data(forKey: saltKey) else {
            throw CryptoError.noMasterPassword
        }
        guard let stored = UserDefaults.standard.data(forKey: verifierKey) else {
            throw CryptoError.noMasterPassword
        }
        let derived = try deriveKey(password: password, salt: salt)
        guard constantTimeEqual(verifierData(from: derived), stored) else {
            throw CryptoError.wrongPassword
        }
        key = derived
        isUnlocked = true
        storeKeyInKeychain(derived)
    }

    func lock() {
        key = nil
        isUnlocked = false
    }

    /// 忘记主密码时调用：删除主密码校验数据，使应用回到初始设置状态。
    /// 注意：这不会也无法解密任何已保存的密码密文，调用方需先清空所有密文字段。
    func resetMasterPassword() {
        UserDefaults.standard.removeObject(forKey: saltKey)
        UserDefaults.standard.removeObject(forKey: verifierKey)
        deleteKeyFromKeychain()
        key = nil
        isUnlocked = false
    }

    // MARK: - Touch ID 解锁

    enum BiometricUnlockResult {
        case success
        case cancelled
        case failed
        case keyMissing
    }

    /// 钥匙串中是否已保存可供生物识别解锁的密钥
    var isBiometricUnlockAvailable: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// 通过 Touch ID（或设备密码，无指纹机型自动回退）解锁。
    /// 密钥存于系统钥匙串并标记必须用户在场才能读取。
    func unlockWithBiometric(completion: @escaping (BiometricUnlockResult) -> Void) {
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "解锁 ClaudeAccountFee 账号保险库"
        ) { success, error in
            guard success else {
                DispatchQueue.main.async {
                    if let error = error as? LAError, error.code == .userCancel {
                        completion(.cancelled)
                    } else {
                        completion(.failed)
                    }
                }
                return
            }
            let loaded = self.loadKeyFromKeychain(context: context)
            DispatchQueue.main.async {
                if let loaded {
                    self.key = loaded
                    self.isUnlocked = true
                    completion(.success)
                } else {
                    completion(.keyMissing)
                }
            }
        }
    }

    private let keychainService = "com.tequila.claudeaccount"
    private let keychainAccount = "vaultKey"

    private func storeKeyInKeychain(_ key: SymmetricKey) {
        deleteKeyFromKeychain()
        var keyBytes = Data()
        key.withUnsafeBytes { keyBytes.append(contentsOf: $0) }
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyBytes,
            kSecAttrAccessControl as String: accessControl,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain(context: LAContext) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func deleteKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func encrypt(_ plaintext: String) -> Data? {
        guard let key, let data = plaintext.data(using: .utf8) else { return nil }
        return try? AES.GCM.seal(data, using: key).combined
    }

    func decrypt(_ cipher: Data) -> String? {
        guard let key,
              let box = try? AES.GCM.SealedBox(combined: cipher),
              let data = try? AES.GCM.open(box, using: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        pbkdf2SHA256(password: Data(password.utf8), salt: salt, iterations: iterations, keyLength: 32)
    }

    /// 标准 PBKDF2（HMAC-SHA256，CryptoKit 未内置，此处按 RFC 2898 实现）
    private func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyLength: Int) -> SymmetricKey {
        let prf = HMAC<SHA256>.self
        let hashLength = SHA256.byteCount
        let blockCount = (keyLength + hashLength - 1) / hashLength

        var derived = Data()
        derived.reserveCapacity(blockCount * hashLength)

        for blockIndex in 1...blockCount {
            var message = salt
            withUnsafeBytes(of: UInt32(blockIndex).bigEndian) {
                message.append(contentsOf: $0)
            }

            var u = Data(prf.authenticationCode(for: message, using: .init(data: password)))
            var result = u
            for _ in 1..<iterations {
                u = Data(prf.authenticationCode(for: u, using: .init(data: password)))
                for index in result.indices {
                    result[index] ^= u[index]
                }
            }
            derived.append(result)
        }

        return SymmetricKey(data: derived.prefix(keyLength))
    }

    private func verifierData(from key: SymmetricKey) -> Data {
        var material = Data()
        key.withUnsafeBytes { material.append(contentsOf: $0) }
        material.append(Data("ClaudeAccount.verifier".utf8))
        return Data(SHA256.hash(data: material))
    }

    /// 恒定时间比较，避免时序侧信道泄露校验值匹配程度
    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(lhs, rhs) {
            diff |= x ^ y
        }
        return diff == 0
    }

    enum CryptoError: Error {
        case noMasterPassword
        case wrongPassword
    }
}
