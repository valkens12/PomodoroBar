import AVFoundation
import AppKit
import Foundation

// Centralizes the app's audio cues. Everything is best-effort: if playback
// can't be set up on the current machine we fall back gracefully and never
// crash. All playback happens on the main thread because it is triggered from
// the MainActor timer.
enum SoundManager {

  /// Plays the phase-change alarm: a warm, synthesized bell chime that rings
  /// *up* when returning to focus and *down* into a break, so the two
  /// directions are audibly distinct. Falls back to a system sound if the
  /// synthesized audio can't be played. No-op if nothing can be resolved.
  static func playAlarm(for incoming: PomodoroTimer.Phase) {
    MainActor.assumeIsolated {
      let chime = incoming == .focus ? focusChime : breakChime
      if let chime, playChime(chime) {
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

  // MARK: - Synthesized chimes (generated once, cached)

  /// C5–E5–G5, ascending and bright: "back to it."
  private static let focusChime: Data? = ChimeSynth.render(
    notes: [523.25, 659.25, 783.99],
    noteSpacing: 0.13,
    noteDuration: 0.55,
    decay: 6.5,
    partials: ChimeSynth.brightPartials,
  )

  /// E5–C5–G4, descending and warm: "ease off."
  private static let breakChime: Data? = ChimeSynth.render(
    notes: [659.25, 523.25, 392.00],
    noteSpacing: 0.16,
    noteDuration: 0.70,
    decay: 4.5,
    partials: ChimeSynth.warmPartials,
  )
}

// MARK: - ChimeSynth

/// Renders a short additive-synthesis bell chime to an in-memory WAV blob.
/// Each note is a small stack of decaying sine partials with a soft attack;
/// notes are staggered so they ring together. Kept private to `SoundManager`
/// — it exists only to feed `AVAudioPlayer(data:)`, so nothing ships on disk.
private enum ChimeSynth {

  typealias Partial = (ratio: Double, amp: Double)

  static let sampleRate: Double = 44_100
  private static let attackSeconds: Double = 0.006
  private static let peakAmplitude: Float = 0.9

  /// More upper partials → a brighter, glassier ring.
  static let brightPartials: [Partial] = [
    (1.0, 1.0), (2.01, 0.5), (3.0, 0.28), (4.2, 0.12),
  ]

  /// Fewer, lower partials → a rounder, softer tone.
  static let warmPartials: [Partial] = [
    (1.0, 1.0), (2.0, 0.35), (2.99, 0.12),
  ]

  static func render(
    notes: [Double],
    noteSpacing: Double,
    noteDuration: Double,
    decay: Double,
    partials: [Partial],
  ) -> Data? {
    let tailPadding = 0.05
    let totalSeconds =
      noteSpacing * Double(max(notes.count - 1, 0)) + noteDuration + tailPadding
    let frameCount = Int(totalSeconds * sampleRate)
    guard frameCount > 0 else { return nil }

    var samples = [Float](repeating: 0, count: frameCount)
    let noteFrames = Int(noteDuration * sampleRate)
    let attackFrames = max(1, Int(attackSeconds * sampleRate))

    for (index, frequency) in notes.enumerated() {
      let startFrame = Int(Double(index) * noteSpacing * sampleRate)
      addNote(
        to: &samples,
        startFrame: startFrame,
        noteFrames: noteFrames,
        attackFrames: attackFrames,
        frequency: frequency,
        decay: decay,
        partials: partials,
      )
    }

    normalize(&samples)
    return wav(from: samples)
  }

  private static func addNote(
    to samples: inout [Float],
    startFrame: Int,
    noteFrames: Int,
    attackFrames: Int,
    frequency: Double,
    decay: Double,
    partials: [Partial],
  ) {
    for offset in 0..<noteFrames {
      let frame = startFrame + offset
      guard frame < samples.count else { break }
      let t = Double(offset) / sampleRate
      let envelope = exp(-decay * t)
      let attack = offset < attackFrames ? Double(offset) / Double(attackFrames) : 1.0
      var value = 0.0
      for partial in partials {
        value += partial.amp * sin(2.0 * .pi * frequency * partial.ratio * t)
      }
      samples[frame] += Float(value * envelope * attack)
    }
  }

  private static func normalize(_ samples: inout [Float]) {
    let peak = samples.map(abs).max() ?? 0
    guard peak > 0 else { return }
    let scale = peakAmplitude / peak
    for index in samples.indices {
      samples[index] *= scale
    }
  }

  private static func wav(from samples: [Float]) -> Data {
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let rate = UInt32(sampleRate)
    let bytesPerSample = UInt32(bitsPerSample / 8)
    let byteRate = rate * UInt32(channels) * bytesPerSample
    let blockAlign = channels * UInt16(bytesPerSample)
    let dataSize = UInt32(samples.count) * bytesPerSample

    var data = Data()
    func appendASCII(_ text: String) { data.append(contentsOf: text.utf8) }
    func appendU32(_ value: UInt32) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    func appendU16(_ value: UInt16) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    appendASCII("RIFF")
    appendU32(36 + dataSize)
    appendASCII("WAVE")
    appendASCII("fmt ")
    appendU32(16)  // PCM subchunk size
    appendU16(1)  // PCM format
    appendU16(channels)
    appendU32(rate)
    appendU32(byteRate)
    appendU16(blockAlign)
    appendU16(bitsPerSample)
    appendASCII("data")
    appendU32(dataSize)

    for sample in samples {
      let clamped = max(-1, min(1, sample))
      let intSample = Int16(clamped * Float(Int16.max))
      appendU16(UInt16(bitPattern: intSample))
    }
    return data
  }
}
