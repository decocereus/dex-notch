import Foundation

@MainActor
final class CodexUsageController {
  private let model: DexModel
  private let reader: any CodexUsageReading
  private let refreshInterval: Duration
  private var refreshTask: Task<Void, Never>?

  init(
    model: DexModel,
    reader: any CodexUsageReading = CodexUsageClient(),
    refreshInterval: Duration = .seconds(10 * 60)
  ) {
    self.model = model
    self.reader = reader
    self.refreshInterval = refreshInterval
  }

  func start() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await refresh()
        do {
          try await Task.sleep(for: refreshInterval)
        } catch {
          return
        }
      }
    }
  }

  func refresh() async {
    do {
      let snapshot = try await reader.readWeeklyUsage()
      model.updateCodexUsage(snapshot)
    } catch {
      // Missing, signed-out, or incompatible Codex installs stay quiet. A
      // previous successful reading remains useful until the next refresh.
    }
  }
}
