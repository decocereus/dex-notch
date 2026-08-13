import Foundation

struct DexThread: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let project: String
  let detail: String
  let activity: ThreadActivity
  let usedTokens: Int
  let maximumTokens: Int?

  var usageFraction: Double? {
    guard let maximumTokens, maximumTokens > 0 else { return nil }
    return min(max(Double(usedTokens) / Double(maximumTokens), 0), 1)
  }

  var usagePercentage: Int? {
    usageFraction.map { Int(($0 * 100).rounded()) }
  }
}
