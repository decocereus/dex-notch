import SwiftUI

struct CompactNotchView: View {
  @ObservedObject var model: DexModel

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 5) {
        ActivityPulse()

        Text(model.connectionState == .connected ? "\(model.activeCount)" : "—")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white.opacity(0.82))
      }
      .padding(.leading, 8)
      .frame(width: NotchGeometry.wingWidth, alignment: .leading)
      .contentShape(Rectangle())
      .onHover(perform: model.updateHover)
      .onTapGesture(perform: model.expand)

      Color.clear
        .frame(width: model.notchWidth)

      HStack(spacing: 4) {
        UsageRing(progress: Double(model.primaryUsagePercentage ?? 0) / 100, size: 13)

        Text(model.primaryUsagePercentage.map(String.init) ?? "—")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white.opacity(0.82))
      }
      .padding(.trailing, 8)
      .frame(width: NotchGeometry.wingWidth, alignment: .trailing)
      .contentShape(Rectangle())
      .onHover(perform: model.updateHover)
      .onTapGesture(perform: model.expand)
    }
    .frame(width: model.compactWidth, height: model.compactHeight)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Dex, \(model.activeCount) active threads"
    )
    .accessibilityHint("Click to show thread activity")
  }
}

private struct ActivityPulse: View {
  var body: some View {
    ZStack {
      Circle()
        .fill(.cyan.opacity(0.18))
        .frame(width: 10, height: 10)

      Circle()
        .fill(.cyan)
        .frame(width: 4, height: 4)
    }
  }
}
