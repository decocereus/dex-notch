import Foundation
import Testing

@testable import Dex

@Suite("T3 application launcher")
struct T3ApplicationLauncherTests {
  @Test("prefers the stable scheme when both are registered")
  func prefersStableScheme() {
    let selectedURL = T3ApplicationLauncher.preferredPairingRouteURL { _ in true }

    #expect(selectedURL?.absoluteString == "t3code://app/settings/connections")
  }

  @Test("uses the development scheme when it is the registered handler")
  func usesDevelopmentScheme() {
    let selectedURL = T3ApplicationLauncher.preferredPairingRouteURL {
      $0.scheme == "t3code-dev"
    }

    #expect(selectedURL?.absoluteString == "t3code-dev://app/settings/connections")
  }

  @Test("returns no deep link when T3 Code is not installed")
  func returnsNoDeepLink() {
    let selectedURL = T3ApplicationLauncher.preferredPairingRouteURL { _ in false }

    #expect(selectedURL == nil)
  }
}
