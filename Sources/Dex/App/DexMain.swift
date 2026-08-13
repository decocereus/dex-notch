import AppKit

@main
enum DexMain {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let delegate = DexApplicationDelegate()

    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()

    withExtendedLifetime(delegate) {}
  }
}
