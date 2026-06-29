import AppKit
import Foundation

// Centralizes the app's audio cues. Everything is best-effort:
// if a named system sound is unavailable on the current macOS install,
// we fall back gracefully and never crash. All playback happens on the
// main thread because it is triggered from the MainActor timer.
enum SoundManager {

  /// Plays the phase-change cue. Tries Glass, then Ping, then the system
  /// beep. No-op if no sound can be resolved.
  static func playPhaseChange() {
    MainActor.assumeIsolated {
      guard let sound = phaseChangeSound() else { return }
      sound.currentTime = 0
      sound.play()
    }
  }

  /// Plays a very short, subtle tick. Uses "Tink" at a low volume if
  /// available; otherwise silent. Safe to call every second.
  static func playTick() {
    MainActor.assumeIsolated {
      guard let sound = tickSound() else { return }
      sound.volume = tickVolume
      sound.currentTime = 0
      sound.play()
    }
  }

  // MARK: - Private helpers

  private static let tickVolume: Float = 0.25

  private static func phaseChangeSound() -> NSSound? {
    if let glass = NSSound(named: "Glass") {
      return glass
    }
    if let ping = NSSound(named: "Ping") {
      return ping
    }
    // NSSound.beep() is a function, not an NSSound instance, so we return
    // nil and let the caller stay silent rather than fire the system beep
    // unexpectedly. The named sounds above cover macOS 13+.
    return nil
  }

  private static func tickSound() -> NSSound? {
    NSSound(named: "Tink")
  }
}