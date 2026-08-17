import Foundation
import SwiftUI

struct ExpandedThreadsView: View {
  @ObservedObject var model: DexModel
  let onQuit: () -> Void
  let onOpenT3ForPairing: () -> Void
  let onConnect: () -> Void

  var body: some View {
    content
      .onHover(perform: model.updateHover)
      .contextMenu {
        Button("Quit Dex", action: onQuit)
      }
  }

  private var content: some View {
    VStack(spacing: 0) {
      if model.connectionState == .connected {
        WeeklyPaceStrip(usage: model.codexUsage)

        if model.displayedThreads.isEmpty {
          emptyWorkState
        } else {
          ForEach(model.displayedThreads.prefix(4)) { thread in
            LiveThreadRow(thread: thread)
          }
        }
      } else {
        disconnectedState
      }
    }
    .frame(
      width: NotchGeometry.expandedWidth,
      height: model.expandedPanelHeight - model.compactHeight,
      alignment: .top
    )
    .padding(.top, model.compactHeight)
    .foregroundStyle(.white)
  }

  private var emptyWorkState: some View {
    VStack(spacing: 5) {
      Image(systemName: "circle.dotted")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white.opacity(0.28))

      Text("No work in progress")
        .font(.system(size: 11, weight: .semibold, design: .rounded))

      Text("Dex stays quiet until a thread needs tracking.")
        .font(.system(size: 9, design: .rounded))
        .foregroundStyle(.white.opacity(0.38))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.bottom, 24)
  }

  private var disconnectedState: some View {
    Group {
      switch model.connectionState {
      case .connecting:
        connectionState(
          icon: "arrow.triangle.2.circlepath",
          title: "Connecting to T3 Code…",
          detail: "Exchanging a read-only pairing credential.",
          showsProgress: true
        )
      case .incompatible(let message):
        connectionState(
          icon: "exclamationmark.triangle",
          title: "Couldn’t connect",
          detail: message,
          showsPairingActions: true
        )
      case .disconnected:
        connectionState(
          icon: "bolt.horizontal.circle",
          title: "T3 Code isn’t connected",
          detail: "T3 Code → Settings → Connections → Create pairing link",
          showsPairingActions: true
        )
      case .connected:
        connectionState(
          icon: "checkmark.circle",
          title: "Connected",
          detail: "No work is currently in progress."
        )
      }
    }
  }

  private func connectionState(
    icon: String,
    title: String,
    detail: String,
    showsPairingActions: Bool = false,
    showsProgress: Bool = false
  ) -> some View {
    VStack(spacing: 8) {
      if showsProgress {
        ProgressView()
          .controlSize(.small)
      } else {
        Image(systemName: icon)
          .font(.system(size: 21, weight: .medium))
          .foregroundStyle(.white.opacity(0.45))
      }

      Text(title)
        .font(.system(size: 12, weight: .semibold, design: .rounded))

      Text(detail)
        .font(.system(size: 10, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
        .multilineTextAlignment(.center)
        .lineLimit(2)

      if showsPairingActions {
        Button(action: onOpenT3ForPairing) {
          Label("Get pairing link in T3 Code", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityHint("Opens T3 Code so you can get a pairing link from Connections")

        Button("Paste link when ready", action: onConnect)
          .buttonStyle(.plain)
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.68))
          .accessibilityHint("Reads a T3 pairing link from the clipboard")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.bottom, 14)
  }
}

private struct WeeklyPaceStrip: View {
  let usage: CodexUsageSnapshot?

  var body: some View {
    HStack(spacing: 8) {
      Text(paceLabel)
        .foregroundStyle(paceColor)

      Spacer(minLength: 8)

      Text(forecastLabel)
        .foregroundStyle(.white.opacity(0.38))
    }
    .font(.system(size: 9, weight: .medium, design: .rounded))
    .monospacedDigit()
    .padding(.horizontal, 13)
    .frame(height: 34)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.06))
        .frame(height: 1)
        .padding(.horizontal, 12)
    }
    .accessibilityElement(children: .combine)
  }

  private var paceLabel: String {
    guard let usage else { return "Weekly usage unavailable" }
    return usage.pace?.comparisonLabel ?? "Weekly pace unavailable"
  }

  private var paceColor: Color {
    guard let delta = usage?.pace?.deltaPercentage else { return .white.opacity(0.34) }
    if delta > CodexUsagePace.onPaceTolerance { return .orange.opacity(0.82) }
    if delta < -CodexUsagePace.onPaceTolerance { return .cyan.opacity(0.72) }
    return .white.opacity(0.58)
  }

  private var forecastLabel: String {
    guard let usage else { return "" }
    if let exhaustionAt = usage.pace?.projectedExhaustionAt {
      return "Runs out \(relative(exhaustionAt))"
    }
    if let resetsAt = usage.resetsAt {
      return "Resets \(relative(resetsAt))"
    }
    return "Reset unavailable"
  }

  private func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

private struct LiveThreadRow: View {
  let thread: DexThread

  var body: some View {
    HStack(spacing: 8) {
      ActivityGlyph(activity: thread.activity, size: 22)

      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 6) {
          Text(thread.title)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .lineLimit(1)

          Spacer(minLength: 5)

          Text(thread.activity.label)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(thread.activity.tint.opacity(0.78))
        }

        HStack(spacing: 5) {
          Text(thread.checkoutLabel)
            .lineLimit(1)

          if let usage = thread.usagePercentage, usage >= 70 {
            Text("\(usage)% ctx")
              .foregroundStyle(usage >= 85 ? .orange.opacity(0.8) : .white.opacity(0.42))
          }
        }
        .font(.system(size: 8.5, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.34))
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.055))
        .frame(height: 1)
        .padding(.horizontal, 12)
    }
    .help(thread.detail)
  }
}

private struct ActivityGlyph: View {
  let activity: ThreadActivity
  let size: CGFloat

  var body: some View {
    Image(systemName: activity.symbolName)
      .font(.system(size: size * 0.38, weight: .semibold))
      .foregroundStyle(activity.tint)
      .frame(width: size, height: size)
      .background(activity.tint.opacity(0.1), in: Circle())
  }
}
