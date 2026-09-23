import MenuCalCore
import SwiftUI

/// The events of the selected day, under the grid, inside the same panel: a second window would
/// close this transient one the moment it took the focus. Read only; a double click hands the
/// event to Calendar.
struct DayListView: View {
  let model: CalendarViewModel

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  var body: some View {
    let metrics = model.metrics
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Text(model.footerText)
          .font(model.typography.listHeader)
          .foregroundStyle(Palette.primary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if let holiday = model.selectedHoliday {
          Text(holiday.name)
            .font(model.typography.footer)
            .foregroundStyle(Palette.dayOff)
            .lineLimit(1)
        }
        if let vacation = model.selectedVacationName {
          Text(vacation)
            .font(model.typography.footer)
            .foregroundStyle(Palette.vacation)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Button {
          model.setDayList(open: false)
        } label: {
          Image(systemName: "chevron.up")
            .font(model.typography.chevron)
            .frame(width: metrics.navButtonSize.width, height: metrics.navButtonSize.height)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.secondary)
        .focusable(false)
        .accessibilityLabel(L("events.closeList"))
        .help(L("events.closeList"))
      }
      .padding(.leading, 6)
      .frame(height: metrics.navCapsuleHeight)

      if model.dayRows.isEmpty {
        Text(L("events.none"))
          .font(model.typography.footer)
          .foregroundStyle(Palette.tertiary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView(.vertical) {
          VStack(spacing: 0) {
            ForEach(model.dayRows) { row in
              EventRowView(row: row, metrics: metrics, typography: model.typography, useTags: differentiateWithoutColor)
                .onTapGesture(count: 2) { model.openInCalendar(row) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: L("events.openInCalendar")) { model.openInCalendar(row) }
            }
          }
        }
        .scrollIndicators(.automatic)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L("events.listLabel", model.footerText))
  }
}

/// One row: the time on the left, a mark in the group's colour, the title.
private struct EventRowView: View {
  let row: EventRow
  let metrics: Metrics
  let typography: Typography
  /// Under "Differentiate without colour" the mark becomes a three letter tag of the group.
  let useTags: Bool

  var body: some View {
    HStack(spacing: 8) {
      Text(row.timeText)
        .font(row.isAllDay ? typography.eventAllDay : typography.eventTime)
        .foregroundStyle(Palette.secondary)
        .frame(width: metrics.eventTimeWidth, alignment: .trailing)
        .lineLimit(1)
      if useTags {
        Text(String(row.groupName.prefix(3)).uppercased())
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(Palette.group(row.groupPaletteIndex))
          .frame(width: 24)
      } else {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(Palette.group(row.groupPaletteIndex))
          .frame(width: 3, height: 15)
      }
      Text(row.title)
        .font(typography.eventTitle)
        .foregroundStyle(Palette.primary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .frame(height: metrics.eventRowHeight)
    .contentShape(Rectangle())
    .help(row.calendarTitle)
  }
}
