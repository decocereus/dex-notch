import Combine
import Foundation

@MainActor
final class DexModel: ObservableObject {
  @Published var isExpanded = false
  @Published private(set) var notchWidth: CGFloat = 180
  @Published private(set) var compactWidth: CGFloat = 336
  @Published private(set) var compactHeight: CGFloat = 38

  @Published private(set) var connectionState: ConnectionState
  @Published private(set) var threads: [DexThread]

  private var collapseTask: Task<Void, Never>?

  init(connectionState: ConnectionState = .disconnected, threads: [DexThread] = []) {
    self.connectionState = connectionState
    self.threads = threads
  }

  var activeCount: Int {
    threads.lazy.filter(\.activity.isActive).count
  }

  var attentionCount: Int {
    threads.lazy.filter { $0.activity == .needsApproval || $0.activity == .needsInput }.count
  }

  var primaryUsagePercentage: Int? {
    threads.first(where: { $0.activity == .working })?.usagePercentage
      ?? threads.first?.usagePercentage
  }

  func expand() {
    collapseTask?.cancel()
    isExpanded = true
  }

  func updateHover(_ isHovering: Bool) {
    collapseTask?.cancel()

    if isHovering {
      isExpanded = true
      return
    }

    collapseTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(360))
      guard !Task.isCancelled else { return }
      self?.isExpanded = false
    }
  }

  func collapse() {
    collapseTask?.cancel()
    isExpanded = false
  }

  func updateGeometry(_ geometry: NotchGeometry) {
    notchWidth = geometry.notchWidth
    compactWidth = geometry.compactFrame.width
    compactHeight = geometry.compactFrame.height
  }

  func updateConnection(_ state: ConnectionState, threads: [DexThread]) {
    connectionState = state
    self.threads = threads
  }
}

extension DexModel {
  enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case incompatible(String)
  }
}
