import Foundation

struct CodexUsageSnapshot: Equatable, Sendable {
  let remainingPercentage: Int
  let usedPercentage: Int
  let resetsAt: Date?
  let observedAt: Date

  var pace: CodexUsagePace? {
    CodexUsagePace(snapshot: self)
  }
}

struct CodexUsagePace: Equatable, Sendable {
  static let weeklyDuration: TimeInterval = 7 * 24 * 60 * 60
  static let onPaceTolerance = 2

  let deltaPercentage: Int
  let projectedExhaustionAt: Date?
  let lastsToReset: Bool

  init?(snapshot: CodexUsageSnapshot) {
    guard let resetsAt = snapshot.resetsAt else { return nil }
    let remainingTime = resetsAt.timeIntervalSince(snapshot.observedAt)
    guard remainingTime > 0, remainingTime <= Self.weeklyDuration else { return nil }

    let elapsedTime = Self.weeklyDuration - remainingTime
    let expectedUsed = elapsedTime / Self.weeklyDuration * 100
    deltaPercentage = Int((Double(snapshot.usedPercentage) - expectedUsed).rounded())

    guard snapshot.usedPercentage > 0, elapsedTime > 0 else {
      projectedExhaustionAt = nil
      lastsToReset = true
      return
    }

    let usedPerSecond = Double(snapshot.usedPercentage) / elapsedTime
    let remainingUsage = Double(max(100 - snapshot.usedPercentage, 0))
    let exhaustionAt = snapshot.observedAt.addingTimeInterval(remainingUsage / usedPerSecond)
    lastsToReset = exhaustionAt >= resetsAt
    projectedExhaustionAt = lastsToReset ? nil : exhaustionAt
  }

  var comparisonLabel: String {
    if abs(deltaPercentage) <= Self.onPaceTolerance { return "On pace" }
    if deltaPercentage > 0 { return "\(deltaPercentage)% over pace" }
    return "\(abs(deltaPercentage))% in reserve"
  }
}

protocol CodexUsageReading: Sendable {
  func readWeeklyUsage() async throws -> CodexUsageSnapshot
}
