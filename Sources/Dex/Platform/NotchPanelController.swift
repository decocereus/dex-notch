import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
  private let model: DexModel
  private let panel: NotchPanel

  private var geometry: NotchGeometry?
  private var expansionCancellable: AnyCancellable?
  private var outsideClickMonitor: Any?

  init(model: DexModel) {
    self.model = model
    self.panel = NotchPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    super.init()

    configurePanel()
    observeModel()
    observeDisplays()
    observeOutsideClicks()
  }

  func present() {
    updateGeometry(animated: false)
    panel.orderFrontRegardless()
  }

  private func configurePanel() {
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    panel.sharingType = .readOnly
    panel.title = "Dex"
    panel.becomesKeyOnlyIfNeeded = true
    panel.isMovable = false
    panel.acceptsMouseMovedEvents = true
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle,
    ]

    let rootView = DexRootView(
      model: model,
      onQuit: { NSApp.terminate(nil) },
      onConnect: { [weak self] in self?.connectFromPasteboard() }
    )
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.sizingOptions = []
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView
  }

  var onConnectRequested: (() -> Void)?

  private func connectFromPasteboard() {
    onConnectRequested?()
  }

  private func observeModel() {
    expansionCancellable = model.$isExpanded
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] isExpanded in
        self?.updatePanelFrame(animated: true)
        if isExpanded {
          self?.panel.orderFrontRegardless()
        }
      }
  }

  private func observeDisplays() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeSpaceChanged),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )
  }

  private func observeOutsideClicks() {
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        if !self.panel.frame.contains(NSEvent.mouseLocation) {
          self.model.collapse()
        }
      }
    }
  }

  @objc
  private func screenParametersChanged() {
    updateGeometry(animated: false)
  }

  @objc
  private func activeSpaceChanged() {
    panel.orderFrontRegardless()
  }

  private func updateGeometry(animated: Bool) {
    guard let screen = preferredScreen else { return }

    let geometry = NotchGeometry.resolve(
      screenFrame: screen.frame,
      safeAreaTop: screen.safeAreaInsets.top,
      auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
      auxiliaryTopRightArea: screen.auxiliaryTopRightArea
    )

    self.geometry = geometry
    model.updateGeometry(geometry)
    updatePanelFrame(animated: animated)
  }

  private func updatePanelFrame(animated: Bool) {
    guard let geometry else { return }
    let frame = model.isExpanded ? geometry.expandedFrame : geometry.compactFrame
    guard animated else {
      panel.setFrame(frame, display: true)
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.24
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      panel.animator().setFrame(frame, display: true)
    }
  }

  private var preferredScreen: NSScreen? {
    NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
      ?? NSScreen.main
      ?? NSScreen.screens.first
  }
}
