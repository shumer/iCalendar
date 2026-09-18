import SwiftUI

/// The content of the calendar panel: header, weekday row and grid, footer. The glass under it
/// belongs to the panel, not to this view.
struct CalendarPanelView: View {
  let model: CalendarViewModel

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    let metrics = model.metrics
    VStack(spacing: metrics.sectionSpacing) {
      PopoverHeader(model: model)
      MonthGridView(model: model)
      if model.preferences.showsFullDate {
        footer
      }
    }
    .padding(metrics.panelPadding)
    .frame(width: model.panelSize.width, height: model.panelSize.height, alignment: .top)
    .overlay {
      if contrast == .increased {
        RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
          .strokeBorder(Palette.separator, lineWidth: 1)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L("panel.accessibilityLabel"))
  }

  /// The full date, or a shorter date and the holiday's name when the selected day is one. The
  /// date comes first, so that a long name is what gets cut and never the date.
  private var footerLabel: Text {
    guard let holiday = model.selectedHoliday else {
      return Text(model.footerText).foregroundStyle(Palette.secondary)
    }
    return Text(holiday.date + "  ·  ").foregroundStyle(Palette.secondary)
      + Text(holiday.name).foregroundStyle(Palette.holiday)
  }

  private var footer: some View {
    let metrics = model.metrics
    return footerLabel
      .font(model.typography.footer)
      .lineLimit(1)
      .truncationMode(.tail)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity)
      .frame(height: metrics.footerHeight)
      .background(
        Palette.hoverFill,
        in: RoundedRectangle(cornerRadius: metrics.innerCornerRadius, style: .continuous))
      .contentTransition(.opacity)
      .accessibilityLabel(
        L(
          "accessibility.selectedDate",
          [model.footerText, model.selectedHoliday?.name].compactMap { $0 }.joined(separator: ", ")))
  }
}
