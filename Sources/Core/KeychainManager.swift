import Foundation
import Security
import LocalAuthentication

/// macOS Keychain ve Touch ID ile güvenli arşiv parolası yönetimi
public final class KeychainManager: @unchecked Sendable {
    public static let shared = KeychainManager()

    private let serviceName = "com.coffer.passwords"

    private init() {}

    /// Arşiv dosyası için kaydedilmiş parolayı getirir (Varsa Touch ID ile doğrular)
    public func retrievePassword(for archiveName: String, useBiometrics: Bool = false) async -> String? {
        if useBiometrics {
            let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Coffer: '\(archiveName)' şifreli arşivinin parolasını çözmek için Touch ID kullanın."
                do {
                    let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                    guard success else { return nil }
                } catch {
                    return nil
                }
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: archiveName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    /// Arşiv parolasını Keychain'e kaydeder
    public func savePassword(_ password: String, for archiveName: String) {
        guard let data = password.data(using: .utf8) else { return }

        // Önce eskisi varsa sil
        deletePassword(for: archiveName)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: archiveName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// Parolayı Keychain'den siler
    public func deletePassword(for archiveName: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: archiveName
        ]
        SecItemDelete(query as CFDictionary)
    }
}
