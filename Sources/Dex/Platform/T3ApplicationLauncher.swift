import AppKit
import Foundation

enum T3ApplicationLauncher {
  static let pairingRouteURLs = [
    URL(string: "t3code://app/settings/connections")!,
    URL(string: "t3code-dev://app/settings/connections")!,
  ]

  static let websiteURL = URL(string: "https://t3.codes")!

  @MainActor
  static func openForPairing(workspace: NSWorkspace = .shared) {
    guard let url = preferredPairingRouteURL(
      canOpen: { workspace.urlForApplication(toOpen: $0) != nil }
    ) else {
      workspace.open(websiteURL)
      return
    }

    workspace.open(url)
  }

  static func preferredPairingRouteURL(
    canOpen: (URL) -> Bool
  ) -> URL? {
    pairingRouteURLs.first(where: canOpen)
  }
}
