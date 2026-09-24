import MenuCalCore
import SwiftUI

/// The events of the selected day, under the grid, inside the same panel: a second window would
/// close this transient one the moment it took the focus. Read only; a double click hands the
/// event to Calendar. A row of group chips narrows the list for this run of the app.
struct DayListView: View {
  let model: CalendarViewModel

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let metrics = model.metrics
    VStack(spacing: 0) {
      header
      if !model.filterChips.isEmpty {
        chips
          .padding(.bottom, 4)
      }
      if model.dayRows.isEmpty {
        Text(model.listFilter.isEmpty ? L("events.none") : L("events.none.group", model.filterNames))
          .font(model.typography.footer)
          .foregroundStyle(Palette.tertiary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityLabel(model.listFilter.isEmpty ? L("events.none") : L("events.none.group.spoken", model.filterNames))
      } else {
        ScrollView(.vertical) {
          VStack(spacing: 0) {
            ForEach(model.dayRows) { row in
              EventRowView(row: row, metrics: metrics, typography: model.typography, useTags: differentiateWithoutColor)
                .onTapGesture(count: 2) { model.openInCalendar(row) }
                .help(tooltip(row))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(row))
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

  private var header: some View {
    let metrics = model.metrics
    return HStack(spacing: 6) {
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
  }

  /// One chip per group. Chosen: a tint of the group's colour; not chosen: the name in secondary
  /// with the group's dot. The weight never changes, so the widths stay put.
  private var chips: some View {
    let metrics = model.metrics
    return HStack(spacing: metrics.groupChipSpacing) {
      ForEach(model.filterChips) { group in
        let chosen = model.listFilter.contains(group.id)
        Button {
          model.toggleFilter(group.id, only: NSApp.currentEvent?.modifierFlags.contains(.command) == true)
        } label: {
          HStack(spacing: 4) {
            if differentiateWithoutColor {
              Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 8)
                .opacity(chosen ? 1 : 0)
            } else {
              Circle()
                .fill(Palette.group(group.paletteIndex))
                .frame(width: metrics.groupChipDot, height: metrics.groupChipDot)
            }
            Text(group.name)
              .font(model.typography.groupChip)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .foregroundStyle(chosen ? Palette.primary : Palette.secondary)
          .padding(.horizontal, metrics.groupChipPaddingH)
          .frame(height: metrics.groupChipRowHeight)
          .frame(maxWidth: model.hoveredChip == group.id ? nil : metrics.groupChipMaxWidth)
          // Without this the row squeezes the widened chip back to make room for the others.
          .fixedSize(horizontal: model.hoveredChip == group.id, vertical: false)
          .background(chipFill(group, chosen: chosen), in: Capsule())
          .overlay {
            if chosen {
              Capsule().strokeBorder(
                differentiateWithoutColor ? Palette.separator : Palette.group(group.paletteIndex).opacity(Tokens.Opacity.chipLine),
                lineWidth: 1)
            }
          }
        }
        .buttonStyle(ChipButtonStyle())
        .focusable(false)
        .onHover { inside in
          if inside { model.hoveredChip = group.id } else if model.hoveredChip == group.id { model.hoveredChip = nil }
        }
        .animation(Motion.hover, value: model.hoveredChip)
        .help(group.name)
        .accessibilityLabel(group.name)
        .accessibilityValue(chosen ? L("events.chip.shown") : L("events.chip.hidden"))
        .accessibilityHint(L("events.chip.hint"))
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
      }
      Spacer(minLength: 0)
    }
    .padding(.leading, 6)
    .frame(height: metrics.groupChipRowHeight)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L("events.chips"))
  }

  private func chipFill(_ group: EventGroup, chosen: Bool) -> Color {
    guard chosen else { return .clear }
    if differentiateWithoutColor { return Palette.pressedFill }
    return Palette.group(group.paletteIndex).opacity(colorScheme == .dark ? Tokens.Opacity.chipFillDark : Tokens.Opacity.chipFillLight)
  }

  private func title(_ row: EventRow) -> String {
    row.title.isEmpty ? L("events.untitled") : row.title
  }

  /// "12:35 - 13:20 · 45 min · Timetable", or "all day · Timetable".
  private func tooltip(_ row: EventRow) -> String {
    var parts: [String] = []
    if row.isAllDay {
      parts.append(row.startText)
    } else {
      parts.append(row.startText + " - " + row.endText)
      let duration = model.durationText(row)
      if !duration.isEmpty { parts.append(duration) }
    }
    if !row.calendarTitle.isEmpty { parts.append(row.calendarTitle) }
    return parts.joined(separator: "  ·  ")
  }

  private func spoken(_ row: EventRow) -> String {
    var parts: [String] = []
    if row.isAllDay {
      parts.append(row.startText)
    } else {
      parts.append(L("events.spokenRange", row.startText, row.endText))
      let duration = model.durationText(row)
      if !duration.isEmpty { parts.append(duration) }
    }
    parts.append(title(row))
    parts.append(row.groupName)
    if !row.calendarTitle.isEmpty { parts.append(row.calendarTitle) }
    return parts.joined(separator: ", ")
  }
}

private struct ChipButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(configuration.isPressed ? Palette.pressedFill : .clear, in: Capsule())
      .contentShape(Capsule())
  }
}

/// One row: the start over the end on the left, a mark in the group's colour, the title.
private struct EventRowView: View {
  let row: EventRow
  let metrics: Metrics
  let typography: Typography
  /// Under "Differentiate without colour" the mark becomes a three letter tag of the group.
  let useTags: Bool

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .trailing, spacing: 0) {
        Text(row.startText)
          .font(row.isAllDay ? typography.eventAllDay : typography.eventTime)
          .foregroundStyle(Palette.secondary)
        if !row.endText.isEmpty {
          Text(row.endText)
            .font(typography.eventEndTime)
            .foregroundStyle(Palette.tertiary)
        }
      }
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
          .frame(width: metrics.eventMarkSize.width, height: metrics.eventMarkSize.height)
      }
      Text(row.title.isEmpty ? L("events.untitled") : row.title)
        .font(typography.eventTitle)
        .foregroundStyle(row.title.isEmpty ? Palette.tertiary : Palette.primary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .frame(height: metrics.eventRowHeight)
    .contentShape(Rectangle())
  }
}
