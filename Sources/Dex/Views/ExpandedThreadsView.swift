import SwiftUI

struct ExpandedThreadsView: View {
  @ObservedObject var model: DexModel
  let onQuit: () -> Void
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
      summary
      if model.connectionState == .connected, let primary = model.threads.first {
        PrimaryThreadRow(thread: primary)

        VStack(spacing: 0) {
          ForEach(Array(model.threads.dropFirst().filter(\.activity.isActive).prefix(2))) {
            thread in
            SecondaryThreadRow(thread: thread)
          }
        }
        .padding(.horizontal, 13)
      } else {
        disconnectedState
      }
    }
    .frame(
      width: NotchGeometry.expandedWidth, height: NotchGeometry.expandedHeight, alignment: .top
    )
    .foregroundStyle(.white)
  }

  private var summary: some View {
    HStack(spacing: 7) {
      Text("Dex")
        .foregroundStyle(.white.opacity(0.9))

      if model.connectionState == .connected {
        Text("·")
          .foregroundStyle(.white.opacity(0.24))
        Text("\(model.activeCount) active")
      }

      Spacer()
    }
    .font(.system(size: 10, weight: .semibold, design: .rounded))
    .foregroundStyle(.white.opacity(0.62))
    .padding(.horizontal, 15)
    .padding(.top, 48)
    .padding(.bottom, 12)
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
          buttonTitle: "Try copied link again"
        )
      case .disconnected:
        connectionState(
          icon: "bolt.horizontal.circle",
          title: "T3 Code isn’t connected",
          detail: "In T3 Code, create a pairing link in Settings → Connections, then copy it.",
          buttonTitle: "Connect copied pairing link"
        )
      case .connected:
        connectionState(
          icon: "checkmark.circle",
          title: "Connected",
          detail: "No threads are available yet."
        )
      }
    }
  }

  private func connectionState(
    icon: String,
    title: String,
    detail: String,
    buttonTitle: String? = nil,
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

      if let buttonTitle {
        Button(buttonTitle, action: onConnect)
          .buttonStyle(.borderedProminent)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.bottom, 24)
  }
}

private struct PrimaryThreadRow: View {
  let thread: DexThread

  var body: some View {
    HStack(spacing: 10) {
      ActivityGlyph(activity: thread.activity, size: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(thread.title)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .lineLimit(1)

        Text(thread.detail)
          .font(.system(size: 10, weight: .regular, design: .rounded))
          .foregroundStyle(.white.opacity(0.44))
          .lineLimit(1)

        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.08))
            if let usageFraction = thread.usageFraction {
              Capsule()
                .fill(thread.activity.tint)
                .frame(width: proxy.size.width * usageFraction)
            }
          }
        }
        .frame(height: 2)
      }

      Text(thread.usagePercentage.map { "\($0)%" } ?? "—")
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.52))
        .frame(width: 28, alignment: .trailing)
    }
    .padding(.horizontal, 12)
    .frame(height: 62)
    .background(.white.opacity(0.045))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .padding(.horizontal, 10)
  }
}

private struct SecondaryThreadRow: View {
  let thread: DexThread

  var body: some View {
    HStack(spacing: 9) {
      ActivityGlyph(activity: thread.activity, size: 22)

      Text(thread.title)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .lineLimit(1)

      Spacer(minLength: 8)

      Text(thread.activity.label)
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(thread.activity.tint.opacity(0.72))

      Text(thread.usagePercentage.map { "\($0)%" } ?? "—")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.34))
        .frame(width: 25, alignment: .trailing)
    }
    .frame(height: 36)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.055))
        .frame(height: 1)
    }
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
