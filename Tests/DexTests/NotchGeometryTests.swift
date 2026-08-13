import CoreGraphics
import Testing

@testable import Dex

struct NotchGeometryTests {
  @Test
  func measuresCameraHousingAndAnchorsFramesToTopCenter() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry.resolve(
      screenFrame: screen,
      safeAreaTop: 38,
      auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 666, height: 38),
      auxiliaryTopRightArea: CGRect(x: 846, y: 944, width: 666, height: 38)
    )

    #expect(geometry.hasCameraHousing)
    #expect(geometry.notchWidth == 180)
    #expect(geometry.compactFrame.maxY == screen.maxY)
    #expect(geometry.compactFrame.midX == screen.midX)
    #expect(geometry.expandedFrame.maxY == screen.maxY)
    #expect(geometry.expandedFrame.midX == screen.midX)
    #expect(geometry.expandedFrame.height == NotchGeometry.expandedHeight)
  }

  @Test
  func fallsBackToTopCenterIslandWithoutCameraHousing() {
    let screen = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
    let geometry = NotchGeometry.resolve(
      screenFrame: screen,
      safeAreaTop: 0,
      auxiliaryTopLeftArea: nil,
      auxiliaryTopRightArea: nil
    )

    #expect(!geometry.hasCameraHousing)
    #expect(geometry.notchWidth == NotchGeometry.fallbackNotchWidth)
    #expect(geometry.compactFrame.height == 32)
    #expect(geometry.compactFrame.midX == screen.midX)
    #expect(geometry.compactFrame.maxY == screen.maxY)
  }
}
