import SwiftUI

struct CompactNotchView: View {
  @ObservedObject var model: DexModel

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 5) {
        ActivityPulse()

        Text(activeLabel)
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white.opacity(0.82))
      }
      .padding(.leading, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .onHover(perform: model.updateHover)
      .onTapGesture(perform: model.expand)

      Color.clear
        .frame(width: model.notchWidth)

      HStack(spacing: 4) {
        Text(weeklyUsageLabel)
          .font(.system(size: model.isExpanded ? 9 : 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white.opacity(0.82))
      }
      .padding(.trailing, 8)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .contentShape(Rectangle())
      .onHover(perform: model.updateHover)
      .onTapGesture(perform: model.expand)
      .help(weeklyUsageHelp)
    }
    .frame(maxWidth: .infinity, minHeight: model.compactHeight, maxHeight: model.compactHeight)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Click to show thread activity")
  }

  private var activeLabel: String {
    guard model.connectionState == .connected else { return "—" }
    return model.isExpanded ? "\(model.activeCount) working" : "\(model.activeCount) live"
  }

  private var weeklyUsageLabel: String {
    guard let usage = model.codexUsage else { return "—" }
    return model.isExpanded
      ? "Weekly \(usage.remainingPercentage)% left"
      : "Wk \(usage.remainingPercentage)%"
  }

  private var weeklyUsageHelp: String {
    guard let usage = model.codexUsage else {
      return "Codex weekly allowance unavailable"
    }
    guard let resetsAt = usage.resetsAt else {
      return "\(usage.remainingPercentage)% of the Codex weekly allowance remaining"
    }
    return "\(usage.remainingPercentage)% of the Codex weekly allowance remaining; resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))"
  }

  private var accessibilityLabel: String {
    guard let usage = model.codexUsage else {
      return "Dex, \(model.activeCount) working threads"
    }
    return "Dex, \(model.activeCount) working threads, \(usage.remainingPercentage) percent of the Codex weekly allowance remaining"
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
