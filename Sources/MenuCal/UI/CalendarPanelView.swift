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
      if model.isDayListOpen {
        DayListView(model: model)
          .frame(height: metrics.dayListHeight)
          .transition(.opacity)
      } else if model.preferences.showsFullDate {
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
    var pieces: [Text] = []
    if let holiday = model.selectedHoliday {
      pieces.append(Text(holiday.date + "  ·  ").foregroundStyle(Palette.secondary))
      pieces.append(Text(holiday.name).foregroundStyle(Palette.dayOff))
    } else {
      pieces.append(Text(model.footerText).foregroundStyle(Palette.secondary))
    }
    if let vacation = model.selectedVacationName {
      pieces.append(Text("  ·  ").foregroundStyle(Palette.secondary))
      pieces.append(Text(vacation).foregroundStyle(Palette.vacation).fontWeight(.semibold))
    }
    return pieces.dropFirst().reduce(pieces[0], +)
  }

  /// While a range is selected, or the selected day is a vacation, the footer is an action bar:
  /// the days on the left, Cancel and Vacation or Remove on the right.
  private var actionBar: some View {
    let metrics = model.metrics
    return HStack(spacing: 6) {
      Text(model.selectedRangeText)
        .font(model.typography.footer)
        .foregroundStyle(Palette.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 4)
      if model.state.hasRange {
        Button(L("vacation.cancel")) { model.clearRange() }
          .buttonStyle(FooterButtonStyle(prominent: false, typography: model.typography))
      }
      if model.vacationAction == .remove {
        Button(L("vacation.remove")) { model.unmarkVacation() }
          .buttonStyle(FooterButtonStyle(prominent: false, typography: model.typography))
      } else {
        Button(L("vacation.title")) { model.markVacation() }
          .buttonStyle(FooterButtonStyle(prominent: true, typography: model.typography))
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, 6)
    .frame(maxWidth: .infinity)
    .frame(height: metrics.footerHeight)
    .background(
      Palette.hoverFill,
      in: RoundedRectangle(cornerRadius: metrics.innerCornerRadius, style: .continuous))
  }

  @ViewBuilder
  private var footer: some View {
    if model.vacationAction != nil {
      actionBar
    } else {
      plainFooter
    }
  }

  private var plainFooter: some View {
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
          [model.footerText, model.selectedHoliday?.name, model.selectedVacationName].compactMap { $0 }.joined(separator: ", ")))
  }
}

/// The small buttons of the footer's action bar: capsules in the footer's own height.
private struct FooterButtonStyle: ButtonStyle {
  let prominent: Bool
  let typography: Typography

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(typography.todayButton)
      .foregroundStyle(prominent ? Palette.onAccent : Palette.primary)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(prominent ? Palette.vacation : Palette.pressedFill, in: Capsule())
      .opacity(configuration.isPressed ? 0.7 : 1)
      .focusable(false)
  }
}
