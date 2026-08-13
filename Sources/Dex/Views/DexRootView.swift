import SwiftUI

struct DexRootView: View {
  @ObservedObject var model: DexModel
  let onQuit: () -> Void
  let onConnect: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var surfaceNamespace

  var body: some View {
    let surface = ZStack(alignment: .top) {
      if model.isExpanded {
        ExpandedThreadsView(model: model, onQuit: onQuit, onConnect: onConnect)
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
      } else {
        CompactNotchView(model: model)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .contentShape(surfaceShape)
    .animation(
      reduceMotion
        ? .easeOut(duration: 0.12)
        : .spring(duration: 0.28, bounce: 0),
      value: model.isExpanded
    )

    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: 18) {
        surface
          .background(
            model.isExpanded ? .black.opacity(0.70) : .black,
            in: surfaceShape
          )
          .glassEffect(
            model.isExpanded
              ? .regular.tint(.black.opacity(0.72)).interactive()
              : .identity,
            in: surfaceShape
          )
          .glassEffectID("dex-surface", in: surfaceNamespace)
      }
    } else {
      surface
        .background(fallbackBackground, in: surfaceShape)
        .shadow(
          color: model.isExpanded ? .black.opacity(0.24) : .clear,
          radius: 16,
          y: 8
        )
    }
  }

  private var surfaceShape: UnevenRoundedRectangle {
    UnevenRoundedRectangle(
      topLeadingRadius: 0,
      bottomLeadingRadius: model.isExpanded ? 22 : 11,
      bottomTrailingRadius: model.isExpanded ? 22 : 11,
      topTrailingRadius: 0
    )
  }

  private var fallbackBackground: some ShapeStyle {
    model.isExpanded ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.black)
  }
}
