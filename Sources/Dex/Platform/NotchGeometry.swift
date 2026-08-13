import CoreGraphics

struct NotchGeometry: Equatable, Sendable {
  static let fallbackNotchWidth: CGFloat = 180
  static let wingWidth: CGFloat = 48
  static let expandedWidth: CGFloat = 344
  static let expandedHeight: CGFloat = 218

  let notchWidth: CGFloat
  let compactFrame: CGRect
  let expandedFrame: CGRect
  let hasCameraHousing: Bool

  static func resolve(
    screenFrame: CGRect,
    safeAreaTop: CGFloat,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?
  ) -> NotchGeometry {
    let measuredGap = cameraHousingWidth(
      leftArea: auxiliaryTopLeftArea,
      rightArea: auxiliaryTopRightArea
    )
    let hasCameraHousing = measuredGap != nil
    let notchWidth = measuredGap ?? fallbackNotchWidth
    let compactHeight = min(max(safeAreaTop, 32), 36)
    let compactWidth = notchWidth + (wingWidth * 2)

    return NotchGeometry(
      notchWidth: notchWidth,
      compactFrame: topCenteredFrame(
        screenFrame: screenFrame,
        width: compactWidth,
        height: compactHeight
      ),
      expandedFrame: topCenteredFrame(
        screenFrame: screenFrame,
        width: max(expandedWidth, compactWidth),
        height: expandedHeight
      ),
      hasCameraHousing: hasCameraHousing
    )
  }

  private static func cameraHousingWidth(
    leftArea: CGRect?,
    rightArea: CGRect?
  ) -> CGFloat? {
    guard let leftArea, let rightArea else { return nil }
    let gap = rightArea.minX - leftArea.maxX
    return gap > 0 ? gap : nil
  }

  private static func topCenteredFrame(
    screenFrame: CGRect,
    width: CGFloat,
    height: CGFloat
  ) -> CGRect {
    CGRect(
      x: screenFrame.midX - (width / 2),
      y: screenFrame.maxY - height,
      width: width,
      height: height
    )
  }
}
