enum ThreadActivity: String, CaseIterable, Sendable {
  case working
  case monitoring
  case needsApproval
  case needsInput
  case completed
  case failed

  var label: String {
    switch self {
    case .working:
      "Working"
    case .monitoring:
      "Monitoring"
    case .needsApproval:
      "Needs approval"
    case .needsInput:
      "Needs input"
    case .completed:
      "Completed"
    case .failed:
      "Failed"
    }
  }

  var symbolName: String {
    switch self {
    case .working:
      "sparkles"
    case .monitoring:
      "eye"
    case .needsApproval:
      "exclamationmark.circle.fill"
    case .needsInput:
      "questionmark.circle.fill"
    case .completed:
      "checkmark.circle.fill"
    case .failed:
      "xmark.circle.fill"
    }
  }

  var isActive: Bool {
    switch self {
    case .working, .monitoring, .needsApproval, .needsInput:
      true
    case .completed, .failed:
      false
    }
  }
}
