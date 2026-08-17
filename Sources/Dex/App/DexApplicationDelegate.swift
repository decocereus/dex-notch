import AppKit

@MainActor
final class DexApplicationDelegate: NSObject, NSApplicationDelegate {
  private var panelController: NotchPanelController?
  private var connectionController: T3ConnectionController?
  private var codexUsageController: CodexUsageController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let model = DexModel()
    if CommandLine.arguments.contains("--expanded") {
      model.isExpanded = true
    }
    let panelController = NotchPanelController(model: model)
    let connectionController = T3ConnectionController(model: model)
    let codexUsageController = CodexUsageController(model: model)
    panelController.onConnectRequested = { connectionController.connectFromPasteboard() }

    self.panelController = panelController
    self.connectionController = connectionController
    self.codexUsageController = codexUsageController
    panelController.present()
    connectionController.start()
    codexUsageController.start()
  }
}
