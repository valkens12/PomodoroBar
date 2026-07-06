import SwiftUI

/// Sheet behind the Statistics window's share button: a live, scaled-down
/// preview of the Focus Card with chevrons to cycle through the visual
/// styles (`FocusShareCardStyle`), and the actual ShareLink at the bottom.
/// The chosen style persists in `AppSettings`, so the sheet reopens on the
/// user's last pick.
struct FocusShareCardPickerView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss

  let data: FocusShareCardData

  /// Half-size preview: 360 x 640 card shows as 180 x 320.
  private static let previewScale: CGFloat = 0.5

  var body: some View {
    let style = settings.shareCardStyle

    VStack(spacing: 14) {
      Text(String(localized: "share.sheet.title", defaultValue: "Share Focus Card"))
        .font(.system(.headline, design: .rounded))

      HStack(spacing: 14) {
        cycleButton(
          offset: -1,
          systemImage: "chevron.left",
          label: String(localized: "share.sheet.previous", defaultValue: "Previous style"),
        )
        cardPreview(style)
        cycleButton(
          offset: 1,
          systemImage: "chevron.right",
          label: String(localized: "share.sheet.next", defaultValue: "Next style"),
        )
      }

      styleIndicator(style)

      HStack {
        Button(String(localized: "skip.confirm.cancel", defaultValue: "Cancel")) {
          dismiss()
        }
        Spacer()
        ShareLink(
          item: FocusShareCardExport(data: data, style: style),
          preview: SharePreview(
            String(localized: "share.preview.title", defaultValue: "My Focus Card"),
            image: FocusShareCardExport(data: data, style: style),
          ),
        ) {
          Label(
            String(localized: "share.sheet.share", defaultValue: "Share"),
            systemImage: "square.and.arrow.up",
          )
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.buttonTint(for: .focus))
      }
    }
    .padding(20)
  }

  // MARK: - Preview

  private func cardPreview(_ style: FocusShareCardStyle) -> some View {
    FocusShareCardView(data: data, style: style)
      .scaleEffect(Self.previewScale)
      .frame(
        width: FocusShareCardView.cardSize.width * Self.previewScale,
        height: FocusShareCardView.cardSize.height * Self.previewScale,
      )
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
      .animation(.easeInOut(duration: 0.2), value: style)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        String(
          format: String(
            localized: "share.sheet.previewA11y",
            defaultValue: "Focus Card preview, %@ style",
          ),
          style.displayName,
        )
      )
  }

  // MARK: - Style Cycling

  private func cycleButton(offset: Int, systemImage: String, label: String) -> some View {
    Button {
      cycleStyle(by: offset)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(label)
  }

  private func cycleStyle(by offset: Int) {
    let all = FocusShareCardStyle.allCases
    guard let index = all.firstIndex(of: settings.shareCardStyle) else {
      settings.shareCardStyle = all[0]
      return
    }
    settings.shareCardStyle = all[(index + offset + all.count) % all.count]
  }

  private func styleIndicator(_ style: FocusShareCardStyle) -> some View {
    VStack(spacing: 6) {
      Text(style.displayName)
        .font(.system(.subheadline, design: .rounded).weight(.medium))
      HStack(spacing: 5) {
        ForEach(FocusShareCardStyle.allCases) { candidate in
          Circle()
            .fill(candidate == style ? Color.primary : Color.primary.opacity(0.25))
            .frame(width: 6, height: 6)
        }
      }
      .accessibilityHidden(true)
    }
  }
}

#if DEBUG
#Preview {
  FocusShareCardPickerView(
    data: FocusShareCardData.make(records: DemoStatisticsData.sampleRecords())
  )
  .environment(AppSettings())
}
#endif
