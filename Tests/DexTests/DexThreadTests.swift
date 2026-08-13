import Foundation
import Testing

@testable import Dex

struct DexThreadTests {
  @Test
  func usageIsClampedAndRounded() {
    let thread = DexThread(
      id: UUID().uuidString,
      title: "Test",
      project: "Dex",
      detail: "Fixture",
      activity: .working,
      usedTokens: 82_400,
      maximumTokens: 128_000
    )

    #expect(thread.usagePercentage == 64)
  }

  @Test
  func usageDoesNotExceedOneHundredPercent() {
    let thread = DexThread(
      id: UUID().uuidString,
      title: "Test",
      project: "Dex",
      detail: "Fixture",
      activity: .working,
      usedTokens: 300,
      maximumTokens: 100
    )

    #expect(thread.usageFraction == 1)
    #expect(thread.usagePercentage == 100)
  }

  @Test
  func usageIsUnavailableWithoutAProviderMaximum() {
    let thread = DexThread(
      id: UUID().uuidString,
      title: "Test",
      project: "Dex",
      detail: "Unknown context size",
      activity: .working,
      usedTokens: 300,
      maximumTokens: nil
    )

    #expect(thread.usageFraction == nil)
    #expect(thread.usagePercentage == nil)
  }
}
