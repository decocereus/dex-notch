import Testing
@testable import Dex

@Suite("Session credential")
struct T3SessionCredentialTests {
  @Test("reads Keychain only once per app session")
  func readsPersistentCredentialOnce() {
    var loadCount = 0
    var credential = T3SessionCredential()

    #expect(credential.value {
      loadCount += 1
      return "first"
    } == "first")
    #expect(credential.value {
      loadCount += 1
      return "second"
    } == "first")
    #expect(loadCount == 1)
  }

  @Test("uses a newly paired credential without another Keychain read")
  func replacesCredentialInMemory() {
    var loadCount = 0
    var credential = T3SessionCredential()
    credential.replace(with: "paired")

    #expect(credential.value {
      loadCount += 1
      return nil
    } == "paired")
    #expect(loadCount == 0)
  }
}
