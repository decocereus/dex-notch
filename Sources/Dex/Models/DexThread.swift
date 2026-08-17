import Foundation

struct DexThread: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let project: String
  let repository: String
  let branch: String?
  let worktreePath: String?
  let detail: String
  let activity: ThreadActivity
  let usedTokens: Int
  let maximumTokens: Int?

  init(
    id: String,
    title: String,
    project: String,
    repository: String? = nil,
    branch: String? = nil,
    worktreePath: String? = nil,
    detail: String,
    activity: ThreadActivity,
    usedTokens: Int,
    maximumTokens: Int?
  ) {
    self.id = id
    self.title = title
    self.project = project
    self.repository = repository ?? project
    self.branch = branch
    self.worktreePath = worktreePath
    self.detail = detail
    self.activity = activity
    self.usedTokens = usedTokens
    self.maximumTokens = maximumTokens
  }

  var usageFraction: Double? {
    guard let maximumTokens, maximumTokens > 0 else { return nil }
    return min(max(Double(usedTokens) / Double(maximumTokens), 0), 1)
  }

  var usagePercentage: Int? {
    usageFraction.map { Int(($0 * 100).rounded()) }
  }

  var checkoutLabel: String {
    var parts = [repository]
    appendIfDistinct(branch, to: &parts)
    appendIfDistinct(shortWorktreePath, to: &parts)
    return parts.joined(separator: "  ·  ")
  }

  private var shortWorktreePath: String? {
    guard let worktreePath, !worktreePath.isEmpty else { return nil }
    let components = URL(fileURLWithPath: worktreePath).pathComponents
      .filter { $0 != "/" }
    guard !components.isEmpty else { return nil }
    return components.suffix(2).joined(separator: "/")
  }

  private func appendIfDistinct(_ value: String?, to parts: inout [String]) {
    guard let value, !value.isEmpty, !parts.contains(value) else { return }
    parts.append(value)
  }
}
