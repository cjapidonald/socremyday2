import Foundation
import Security

struct KeychainStore {
    enum KeychainError: Swift.Error {
        case unexpectedStatus(OSStatus)
    }

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.scoremyday.app") {
        self.service = service
    }

    func string(forKey key: String) throws -> String? {
        guard let data = try data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func bool(forKey key: String) throws -> Bool {
        guard let data = try data(forKey: key), let flag = data.first else { return false }
        return flag != 0
    }

    func set(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        try set(data, forKey: key)
    }

    func set(_ value: Bool, forKey key: String) throws {
        let data = Data([value ? 1 : 0])
        try set(data, forKey: key)
    }

    func removeValue(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func data(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = item as? Data else { return nil }
        return data
    }

    private func set(_ data: Data, forKey key: String) throws {
        do {
            try removeValue(forKey: key)
        } catch KeychainError.unexpectedStatus(let status) where status == errSecItemNotFound {
            // Ignore delete failures when the item does not exist.
        }

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
