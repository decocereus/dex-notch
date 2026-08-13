import SwiftUI

extension ThreadActivity {
  var tint: Color {
    switch self {
    case .working:
      .cyan
    case .monitoring:
      .indigo
    case .needsApproval:
      .orange
    case .needsInput:
      .yellow
    case .completed:
      .green
    case .failed:
      .red
    }
  }
}
