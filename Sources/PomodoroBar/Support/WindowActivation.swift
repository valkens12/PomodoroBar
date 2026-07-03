import AppKit
import SwiftUI

/// Focus handling for real windows opened from the menu bar popover.
///
/// The MenuBarExtra popover is a *non-activating* panel, so opening a window
/// from it leaves the app inactive — the window orders in but never becomes
/// key, and keyboard input goes nowhere. While any such window is open the
/// app temporarily becomes a regular app (`.regular` activation policy,
/// which adds a Dock icon for that span) so the window can hold key focus
/// like any normal window, and the hosting window is made key explicitly the
/// moment it exists.
///
/// The policy is reference-counted: with both Settings and Statistics open,
/// closing one must not drop the app back to accessory under the other.
@MainActor
enum ActivationPolicyCoordinator {
  private static var regularWindowCount = 0

  static func windowAppeared() {
    regularWindowCount += 1
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  static func windowDisappeared() {
    regularWindowCount = max(0, regularWindowCount - 1)
    if regularWindowCount == 0 {
      // Drop back to a pure menu bar app once the last window closes.
      NSApp.setActivationPolicy(.accessory)
    }
  }
}

extension View {
  /// Apply to the root content of any `Window`/`Settings` scene opened from
  /// the popover: switches the app to regular activation for the window's
  /// lifetime and grabs key focus on appearance.
  func regularActivationWindow() -> some View {
    self
      .background(WindowFocusGrabber())
      .onAppear { ActivationPolicyCoordinator.windowAppeared() }
      .onDisappear { ActivationPolicyCoordinator.windowDisappeared() }
  }
}

/// Makes the hosting window key as soon as it exists. `NSApp.activate` alone
/// brings the app forward but does not hand a freshly created window
/// keyboard focus — without this, text fields look editable but ignore
/// typing until the user cmd-tabs away and back.
private struct WindowFocusGrabber: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    FocusGrabberView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  private final class FocusGrabberView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.makeKeyAndOrderFront(nil)
    }
  }
}
