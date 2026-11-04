import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    // AppKit may restore a saved frame after loading the storyboard. Apply the
    // launch size on the next main-loop turn so the 900-point sidebar is shown.
    DispatchQueue.main.async { [weak self] in
      self?.setContentSize(NSSize(width: 1280, height: 720))
    }
  }
}
