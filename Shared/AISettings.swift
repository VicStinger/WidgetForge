import Foundation
import Security

/// Stores the person's own Anthropic API key in the Keychain — never in UserDefaults, never
/// synced anywhere by WidgetForge, and never embedded in the app. AI generation is entirely
/// optional; everything else in WidgetForge works with no key saved at all.
enum APIKeyStore {
    private static let service = "WidgetForge.AnthropicAPIKey"
    private static let account = "default"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the key, or removes it entirely when given an empty string.
    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        let data = Data(trimmed.utf8)
        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if SecItemCopyMatching(matchQuery as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(matchQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var newItem = matchQuery
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Non-sensitive AI settings — just which model to ask for, kept separately from the key so
/// it can live in plain UserDefaults.
enum AISettings {
    /// A sensible, current default. Exposed as an editable field in the Generate sheet so a
    /// future rename of Anthropic's model identifiers doesn't require an app update to fix.
    static let defaultModel = "claude-sonnet-5"

    private static let modelKey = "WidgetForge.AIModel"

    static var model: String {
        get {
            let saved = UserDefaults.standard.string(forKey: modelKey) ?? ""
            return saved.isEmpty ? defaultModel : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }
}
