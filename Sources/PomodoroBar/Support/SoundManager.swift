import AVFoundation
import AppKit
import Foundation

// Centralizes the app's audio cues. Everything is best-effort: if playback
// can't be set up on the current machine we fall back gracefully and never
// crash. All playback happens on the main thread because it is triggered from
// the MainActor timer.
enum SoundManager {

  /// Plays the phase-change alarm: a custom chime bundled as a resource.
  /// Falls back to a system sound if it can't be loaded or played. No-op if
  /// nothing can be resolved.
  static func playAlarm() {
    MainActor.assumeIsolated {
      if let alarmSound, playChime(alarmSound) {
        return
      }
      // Best-effort fallback so a broken audio stack still cues the change.
      let sound = phaseChangeSound()
      sound?.currentTime = 0
      sound?.play()
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

  // MARK: - Playback

  /// Retained so the player isn't deallocated mid-playback. Only one chime
  /// ever plays at a time, so a single slot suffices.
  @MainActor private static var chimePlayer: AVAudioPlayer?

  @MainActor
  private static func playChime(_ data: Data) -> Bool {
    do {
      let player = try AVAudioPlayer(data: data)
      player.prepareToPlay()
      chimePlayer = player
      return player.play()
    } catch {
      return false
    }
  }

  // MARK: - System-sound fallbacks

  private static let tickVolume: Float = 0.25

  private static func phaseChangeSound() -> NSSound? {
    NSSound(named: "Glass") ?? NSSound(named: "Ping")
  }

  private static func tickSound() -> NSSound? {
    NSSound(named: "Tink")
  }

  // MARK: - Custom alarm chime (loaded once, cached)

  private static let alarmSound: Data? = {
    guard let url = Bundle.main.url(forResource: "harp_alarm", withExtension: "wav") else {
      return nil
    }
    return try? Data(contentsOf: url)
  }()
}
