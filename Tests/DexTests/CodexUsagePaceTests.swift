import Foundation
import Testing

@testable import Dex

@Suite("Codex weekly pace")
struct CodexUsagePaceTests {
  private let observedAt = Date(timeIntervalSince1970: 1_800_000_000)

  @Test("reports consumption above the ideal weekly burn")
  func overPaceForecastsExhaustion() throws {
    let snapshot = makeSnapshot(used: 65, daysUntilReset: 3.5)
    let pace = try #require(snapshot.pace)

    #expect(pace.deltaPercentage == 15)
    #expect(pace.comparisonLabel == "15% over pace")
    #expect(pace.projectedExhaustionAt != nil)
    #expect(!pace.lastsToReset)
  }

  @Test("reports allowance held in reserve")
  func reserveLastsUntilReset() throws {
    let snapshot = makeSnapshot(used: 35, daysUntilReset: 3.5)
    let pace = try #require(snapshot.pace)

    #expect(pace.deltaPercentage == -15)
    #expect(pace.comparisonLabel == "15% in reserve")
    #expect(pace.projectedExhaustionAt == nil)
    #expect(pace.lastsToReset)
  }

  @Test("uses a small tolerance for an on-pace reading")
  func onPaceTolerance() throws {
    let snapshot = makeSnapshot(used: 52, daysUntilReset: 3.5)
    let pace = try #require(snapshot.pace)

    #expect(pace.deltaPercentage == 2)
    #expect(pace.comparisonLabel == "On pace")
  }

  private func makeSnapshot(used: Int, daysUntilReset: Double) -> CodexUsageSnapshot {
    CodexUsageSnapshot(
      remainingPercentage: 100 - used,
      usedPercentage: used,
      resetsAt: observedAt.addingTimeInterval(daysUntilReset * 24 * 60 * 60),
      observedAt: observedAt
    )
  }
}
