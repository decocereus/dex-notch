import SwiftUI

struct UsageRing: View {
  let progress: Double
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .stroke(.white.opacity(0.16), lineWidth: 2)

      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(
          usageColor,
          style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private var usageColor: Color {
    switch progress {
    case ..<0.7:
      .cyan
    case ..<0.9:
      .orange
    default:
      .red
    }
  }
}
