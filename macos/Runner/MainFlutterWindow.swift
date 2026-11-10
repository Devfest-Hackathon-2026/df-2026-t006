import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // スマホと同じ縦長の形（9:19.5）で開き、大きさを変えても形を保つ
    let phone = NSSize(width: 414, height: 897)
    self.setContentSize(phone)
    self.contentAspectRatio = NSSize(width: 9, height: 19.5)
    self.contentMinSize = NSSize(width: 300, height: 650)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
