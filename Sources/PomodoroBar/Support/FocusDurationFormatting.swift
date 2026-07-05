import Foundation

/// Compact "45m" / "2h 5m" formatting for a focus-minute total. Switches to
/// an hour-based format once the total exceeds 90 minutes — week/month
/// totals routinely run into the hundreds of minutes, where "375m" reads far
/// worse at a glance than "6h 15m". Shared by every Statistics card and chart
/// that renders a focus-minute total.
func formattedFocusDuration(_ minutes: Int) -> String {
  guard minutes > 90 else { return "\(minutes)m" }
  let hours = minutes / 60
  let remainder = minutes % 60
  return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
}

/// VoiceOver-friendly counterpart to `formattedFocusDuration`, spelling out
/// "hour(s)"/"minute(s)" instead of the compact "h"/"m" suffixes.
func accessibleFocusDuration(_ minutes: Int) -> String {
  guard minutes > 90 else {
    // Two distinct keys for the singular/plural English forms, with English
    // fallbacks — VoiceOver always reads the spelled-out form regardless of
    // how the chart-axis label is rendered.
    if minutes == 1 {
      return String(
        format: String(
          localized: "duration.minuteFocus", defaultValue: "%d minute focus time"
        ),
        minutes,
      )
    }
    return String(
      format: String(
        localized: "duration.minutesFocus", defaultValue: "%d minutes focus time"
      ),
      minutes,
    )
  }
  let hours = minutes / 60
  let remainder = minutes % 60
  if remainder == 0 {
    if hours == 1 {
      return String(
        format: String(
          localized: "duration.hourFocus", defaultValue: "%d hour focus time"
        ),
        hours,
      )
    }
    return String(
      format: String(
        localized: "duration.hoursFocusPlural", defaultValue: "%d hours focus time"
      ),
      hours,
    )
  }
  let hourPart: String = {
    if hours == 1 {
      return String(
        format: String(
          localized: "duration.hourN", defaultValue: "%d hour"
        ),
        hours,
      )
    }
    return String(
      format: String(
        localized: "duration.hoursN", defaultValue: "%d hours"
      ),
      hours,
    )
  }()
  let minutePart: String = {
    if remainder == 1 {
      return String(
        format: String(
          localized: "duration.minuteN", defaultValue: "%d minute"
        ),
        remainder,
      )
    }
    return String(
      format: String(
        localized: "duration.minutesN", defaultValue: "%d minutes"
      ),
      remainder,
    )
  }()
  return String(
    format: String(
      localized: "duration.hoursMinutesFocus",
      defaultValue: "%1$@ %2$@ focus time"
    ),
    hourPart, minutePart,
  )
}
