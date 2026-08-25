import Combine
import Foundation

@MainActor
final class DexModel: ObservableObject {
  static let expandedHeaderHeight: CGFloat = 40

  @Published var isExpanded = false
  @Published private(set) var notchWidth: CGFloat = 180
  @Published private(set) var compactWidth: CGFloat = 336
  @Published private(set) var compactHeight: CGFloat = 38

  @Published private(set) var connectionState: ConnectionState
  @Published private(set) var threads: [DexThread]
  @Published private(set) var displayedThreads: [DexThread]
  @Published private(set) var codexUsage: CodexUsageSnapshot?

  private var collapseTask: Task<Void, Never>?

  init(
    connectionState: ConnectionState = .disconnected,
    threads: [DexThread] = [],
    codexUsage: CodexUsageSnapshot? = nil
  ) {
    self.connectionState = connectionState
    self.threads = threads
    self.displayedThreads = threads
    self.codexUsage = codexUsage
  }

  var activeCount: Int {
    threads.count
  }

  var attentionCount: Int {
    threads.lazy.filter { $0.activity == .needsApproval || $0.activity == .needsInput }.count
  }

  var peakActiveUsagePercentage: Int? {
    threads.lazy
      .filter(\.activity.isActive)
      .compactMap(\.usagePercentage)
      .max()
  }

  var expandedPanelHeight: CGFloat {
    guard connectionState == .connected else { return NotchGeometry.expandedHeight }
    let rowCount = min(displayedThreads.count, 4)
    let threadContentHeight = rowCount == 0 ? 70 : CGFloat(rowCount) * 36
    return compactHeight + Self.expandedHeaderHeight + threadContentHeight + 8
  }

  func expand() {
    collapseTask?.cancel()
    guard !isExpanded else { return }
    displayedThreads = threads
    isExpanded = true
  }

  func updateHover(_ isHovering: Bool) {
    collapseTask?.cancel()

    if isHovering {
      expand()
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

  func updateCodexUsage(_ snapshot: CodexUsageSnapshot) {
    codexUsage = snapshot
  }

  func updateConnection(_ state: ConnectionState, threads: [DexThread]) {
    connectionState = state
    self.threads = threads

    guard state == .connected else {
      displayedThreads = []
      return
    }

    guard isExpanded, !displayedThreads.isEmpty else {
      displayedThreads = threads
      return
    }

    let latestByID = Dictionary(uniqueKeysWithValues: threads.map { ($0.id, $0) })
    displayedThreads = displayedThreads.compactMap { latestByID[$0.id] }
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
