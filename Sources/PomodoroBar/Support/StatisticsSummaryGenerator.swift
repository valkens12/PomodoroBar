import Foundation
import Observation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Produces the short motivational overview shown at the top of the
/// Statistics window, using the on-device Foundation Models LLM.
///
/// Availability is hardware- and OS-gated: the framework exists only on
/// macOS 26+, and `SystemLanguageModel` reports available only on Apple
/// Intelligence machines — which requires Apple Silicon, so Intel Macs
/// (including the handful that run macOS 26) never pass `isSupported` and
/// never see the feature. Everything stays on device; no statistics leave
/// the Mac.
///
/// Summarization of a few numeric lines is squarely inside the on-device
/// model's competence (unlike world knowledge or reasoning), and the
/// prompt is app-generated — no user text is ever interpolated into it.
@MainActor
@Observable
final class StatisticsSummaryGenerator {
  /// Lifecycle of the current summary. `.failed` deliberately carries no
  /// message: a missing pep talk isn't worth an error banner, so the view
  /// renders nothing and the next digest change retries.
  enum State: Equatable {
    case idle
    case generating
    case ready(String)
    case failed
  }

  private(set) var state: State = .idle

  /// The `(digest, darkHumor)` pair the current `state` answers for, so
  /// re-opening the Statistics window with unchanged history *and* an
  /// unchanged tone reuses the finished summary instead of re-running the
  /// model. Either half changing invalidates it — flipping the tone toggle
  /// needs a fresh generation just as much as new history does.
  @ObservationIgnored private var generatedKey: String?

  /// Whether this machine can generate summaries at all. False on Intel
  /// Macs, on macOS before 26, and whenever Apple Intelligence is switched
  /// off or its model is still downloading — the UI hides the card entirely
  /// rather than promising a summary it can't produce.
  static var isSupported: Bool {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return false }
      if case .available = SystemLanguageModel.default.availability {
        return true
      }
      return false
    #else
      return false
    #endif
  }

  /// Generates a fresh summary for `digest` in the requested tone, unless
  /// one is already generated or in flight for that exact `(digest,
  /// darkHumor)` pair. Called from the summary card's `.task(id:)`, so it
  /// re-runs precisely when the statistics underneath it — or the tone
  /// toggle — change.
  ///
  /// `darkHumor` swaps the cheerful default for a deliberately harsh,
  /// sarcastic roast (see `Self.instructions(darkHumor:)`); Apple's model
  /// carries its own safety guardrails that app instructions can't override,
  /// so a `guardrailViolation` here just means the model declined to be
  /// quite that mean — the card hides rather than erroring either way.
  func generate(digest: String, darkHumor: Bool) async {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *), Self.isSupported else { return }
      let key = "\(darkHumor)\u{0}\(digest)"
      guard key != generatedKey else { return }
      generatedKey = key
      state = .generating

      var instructions = Self.instructions(darkHumor: darkHumor)
      // The prompt (the digest) is app-generated English, so left alone the
      // model answers in English regardless of the user's locale. Naming the
      // target language explicitly — only when the model actually supports
      // it — makes the reply match the system language instead.
      if let languageDirective = Self.languageDirective() {
        instructions += " " + languageDirective
      }

      let session = LanguageModelSession(instructions: instructions)
      do {
        let response = try await session.respond(to: digest)
        let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        state = summary.isEmpty ? .failed : .ready(summary)
      } catch {
        // Covers guardrail violations, context overflow, and unsupported
        // locales alike — for a single-shot prompt this small, none is
        // recoverable in-place, so fail quietly and let the next digest (or
        // tone) change try again.
        generatedKey = nil
        state = .failed
      }
    #endif
  }

  #if canImport(FoundationModels)
    /// The two available voices for the summary. The default is deliberately
    /// written to have some personality rather than reading like a status
    /// report; dark humor asks the model to roast the user's *habits and
    /// numbers* rather than the user themselves — savage about the stats,
    /// not genuinely cruel — since that's both the funnier version of "mean"
    /// and the one with any chance of clearing the model's own guardrails.
    private static func instructions(darkHumor: Bool) -> String {
      guard darkHumor else {
        return """
          You are the voice of a Pomodoro focus timer app: upbeat, a little \
          cheeky, and genuinely fun to read — never corporate, never \
          clinical, never a status report. Summarize the user's focus \
          statistics in 2 to 3 short sentences, addressing the user as \
          "you," mentioning one or two concrete numbers, and landing at \
          least one bit of wit, playful exaggeration, or gentle teasing. \
          Plain sentences only: no lists, no headings. At most one emoji, \
          placed naturally, never a string of them. If time procrastinated \
          is included, rib them about it lightly rather than scolding or \
          being gentle about it.
          """
      }
      return """
        You are the voice of a Pomodoro focus timer app in "brutally \
        honest" mode: sharp, sarcastic, and unapologetically mean about the \
        user's focus habits — think a comedy roast, not a pep talk. \
        Summarize the user's focus statistics in 2 to 3 short, cutting \
        sentences, addressing the user as "you" and mentioning one or two \
        concrete numbers. Be savage about wasted time and procrastination \
        if it's included — no encouragement, no consolation, no \
        soft-pedaling. Roast their habits and their numbers, not their \
        worth as a person: no genuine cruelty, no slurs, nothing that \
        discourages them from trying again — just merciless, funny \
        mockery of how they spent their time. Plain sentences only: no \
        lists, no headings. At most one emoji for an extra twist of the \
        knife, never a string of them.
        """
    }

    /// An instruction naming the system's current language ("Always respond
    /// in German."), so the model's reply matches the locale instead of the
    /// English the app-generated prompt happens to be written in. Nil when
    /// the model doesn't list the current language as supported (it then
    /// falls back to its English default rather than risk a garbled reply)
    /// or when the language is English already, where the directive would
    /// just spend tokens confirming the default.
    @available(macOS 26.0, *)
    private static func languageDirective() -> String? {
      let language = Locale.current.language
      guard SystemLanguageModel.default.supportedLanguages.contains(language) else {
        return nil
      }
      guard let code = language.languageCode?.identifier, code != "en" else {
        return nil
      }
      guard let englishName = Locale(identifier: "en").localizedString(forLanguageCode: code)
      else {
        return nil
      }
      return "Always respond in \(englishName)."
    }
  #endif
}
