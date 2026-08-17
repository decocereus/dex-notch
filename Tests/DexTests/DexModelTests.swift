import Testing

@testable import Dex

@Suite("Dex presentation model")
@MainActor
struct DexModelTests {
  @Test("keeps row order stable for one expanded hover session")
  func freezesExpandedThreadOrder() {
    let first = thread(id: "first", detail: "Before")
    let second = thread(id: "second", detail: "Before")
    let model = DexModel(connectionState: .connected, threads: [first, second])

    model.expand()
    model.updateConnection(
      .connected,
      threads: [
        thread(id: "second", detail: "Updated"),
        thread(id: "first", detail: "Updated"),
      ]
    )

    #expect(model.displayedThreads.map(\.id) == ["first", "second"])
    #expect(model.displayedThreads.map(\.detail) == ["Updated", "Updated"])

    model.collapse()
    model.expand()

    #expect(model.displayedThreads.map(\.id) == ["second", "first"])
  }

  @Test("removes work that settles while the strip is open")
  func removesSettledWorkInPlace() {
    let model = DexModel(
      connectionState: .connected,
      threads: [thread(id: "first"), thread(id: "second")]
    )

    model.expand()
    model.updateConnection(.connected, threads: [thread(id: "second")])

    #expect(model.displayedThreads.map(\.id) == ["second"])
  }

  @Test("sizes the expanded strip to its live rows")
  func sizesExpandedStripToContent() {
    let model = DexModel(
      connectionState: .connected,
      threads: [thread(id: "first"), thread(id: "second")]
    )

    let expected = model.compactHeight + 34 + (2 * 36) + 8
    #expect(abs(model.expandedPanelHeight - expected) < 0.001)
  }

  @Test("uses the highest active context usage for the compact signal")
  func reportsHighestActiveUsage() {
    let model = DexModel(
      connectionState: .connected,
      threads: [
        thread(id: "low", usedTokens: 20, maximumTokens: 100),
        thread(id: "high", usedTokens: 72, maximumTokens: 100),
        thread(
          id: "completed",
          activity: .completed,
          usedTokens: 95,
          maximumTokens: 100
        ),
      ]
    )

    #expect(model.peakActiveUsagePercentage == 72)
  }

  private func thread(
    id: String,
    detail: String = "Working",
    activity: ThreadActivity = .working,
    usedTokens: Int = 10,
    maximumTokens: Int? = 100
  ) -> DexThread {
    DexThread(
      id: id,
      title: id.capitalized,
      project: "Dex",
      detail: detail,
      activity: activity,
      usedTokens: usedTokens,
      maximumTokens: maximumTokens
    )
  }
}
