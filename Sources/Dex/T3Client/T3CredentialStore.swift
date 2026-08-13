import Foundation
import Security

struct T3SessionCredential {
  private enum State {
    case unloaded
    case loaded(String?)
  }

  private var state: State = .unloaded

  mutating func value(load: () -> String?) -> String? {
    switch state {
    case .unloaded:
      let credential = load()
      state = .loaded(credential)
      return credential
    case .loaded(let credential):
      return credential
    }
  }

  mutating func replace(with credential: String?) {
    state = .loaded(credential)
  }
}

struct T3CredentialStore: Sendable {
  private let service = "codes.t3.dex"
  private let account = "t3-read-session"

  func load() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func save(_ credential: String) throws {
    let key: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(key as CFDictionary)

    var value = key
    value[kSecValueData as String] = Data(credential.utf8)
    value[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(value as CFDictionary, nil)
    guard status == errSecSuccess else { throw T3ClientError.keychain(status) }
  }

  func remove() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
