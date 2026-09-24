import MenuCalCore
import SwiftUI

/// One day of the grid. DesignSpec section 6: today is a filled circle, selected is a ring, so
/// the two differ by shape and weight and not by colour alone.
struct DayCell: View {
  let day: DayCellModel
  let model: CalendarViewModel

  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let range = model.state.selectedRange
    let isSelected = model.state.hasRange ? range.contains(day.id) : day.id == model.state.selectedDate
    let isFocused = model.showsFocusRing && day.id == model.state.focusedDate

    Button {
      // A Button cannot see modifier keys; the event that fired it can.
      if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
        model.extendSelection(to: day)
      } else {
        model.select(day)
      }
    } label: {
      Text(day.dayNumber)
    }
    .buttonStyle(
      DayCellStyle(
        day: day,
        isSelected: isSelected,
        isFocused: isFocused,
        isHovered: model.hoveredDay == day.id,
        highlightsWeekends: model.preferences.highlightsWeekends,
        isHighContrast: contrast == .increased,
        pulse: day.isToday ? model.state.todayPulseCount : 0,
        accent: model.accent,
        isDark: colorScheme == .dark,
        showsDots: model.showsEventDots,
        showsAdjacentDots: model.eventSettings.settings.showsDotsInAdjacentMonths,
        metrics: model.metrics,
        typography: model.typography))
    .focusable(false)
    .onHover { model.hover(day.id, isInside: $0) }
    .contextMenu {
      if model.preferences.showsVacation {
        if day.isVacation {
          Button(L("vacation.remove")) { model.unmarkVacation(day) }
        } else {
          Button(L("vacation.mark")) { model.markVacation(day) }
        }
      }
    }
    .help(tooltip)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(day.isToday ? L("accessibility.today") : "")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

extension DayCell {
  /// A vacation without a name is still announced and shown as one.
  private var vacationWord: String? {
    guard day.isVacation else { return nil }
    return day.vacationName.flatMap { $0.isEmpty ? nil : $0 } ?? L("vacation.title")
  }

  private var tooltip: String {
    [day.holidayName, vacationWord].compactMap { $0 }.joined(separator: ", ")
  }

  private var accessibilityLabel: String {
    guard day.isVacation, day.vacationName?.isEmpty == true else { return day.accessibilityLabel }
    return day.accessibilityLabel + ", " + L("vacation.title")
  }
}

private struct DayCellStyle: ButtonStyle {
  let day: DayCellModel
  let isSelected: Bool
  let isFocused: Bool
  let isHovered: Bool
  let highlightsWeekends: Bool
  let isHighContrast: Bool
  let pulse: Int
  let accent: Color
  let isDark: Bool
  let showsDots: Bool
  let showsAdjacentDots: Bool
  let metrics: Metrics
  let typography: Typography

  func makeBody(configuration: Configuration) -> some View {
    let size = metrics.dayCellSize
    // With dots on, the circle shrinks inside the same cell and the dots take the strip below;
    // the hit area and the rhythm of the grid do not move.
    let circle = showsDots ? metrics.dayCircleWithDots : size
    configuration.label
      .font(typography.day(isToday: day.isToday, isSelected: isSelected))
      .foregroundStyle(textColor)
      .frame(width: circle, height: circle)
      .background {
        background(isPressed: configuration.isPressed)
      }
      .frame(width: size, height: size, alignment: showsDots ? .top : .center)
      // The band spans the cell, not the circle: with dots on the circle is narrower than the
      // cell, and a band the circle's width would break between days.
      .background(alignment: showsDots ? .top : .center) {
        if let segment = day.vacationSegment {
          VacationBand(segment: segment, columnSpacing: metrics.gridColumnSpacing, isDark: isDark)
            .frame(height: circle)
            .opacity(day.isInCurrentMonth ? 1 : Tokens.Opacity.vacationInAdjacentMonth)
        }
      }
      .overlay(alignment: .bottom) {
        if showsDots, day.isInCurrentMonth || showsAdjacentDots {
          HStack(spacing: metrics.eventDotSpacing) {
            ForEach(day.eventDots, id: \.slot) { dot in
              Circle()
                .fill(Palette.group(dot.paletteIndex))
                .frame(width: metrics.eventDotSize, height: metrics.eventDotSize)
            }
          }
          .frame(height: metrics.eventDotSize)
          .opacity(day.isInCurrentMonth ? 1 : Tokens.Opacity.dayOffInAdjacentMonth)
          .padding(.bottom, (size - circle - metrics.eventDotSize) / 2)
          .accessibilityHidden(true)
        }
      }
      .overlay {
        if isFocused {
          let outset = Tokens.Ring.focus + Tokens.Ring.focusOffset
          Circle()
            .inset(by: -outset)
            .strokeBorder(Palette.focus, lineWidth: Tokens.Ring.focus)
        }
      }
      .opacity(day.isToday && !day.isInCurrentMonth ? Tokens.Opacity.todayInAdjacentMonth : 1)
      // The whole cell is the target, whatever the circle inside it is doing.
      .contentShape(Rectangle())
      .animation(Motion.hover, value: configuration.isPressed)
      .animation(Motion.hover, value: isHovered)
  }

  @ViewBuilder
  private func background(isPressed: Bool) -> some View {
    ZStack {
      Circle()
        .inset(by: day.isToday && day.isVacation ? Tokens.Ring.todayInsetInBand : 0)
        .fill(fill(isPressed: isPressed))
        .scaleEffect(isPressed ? Tokens.Scale.pressed : 1)
        .modifier(TodayPulse(trigger: pulse))
      if isSelected {
        if day.isToday {
          Circle()
            .inset(by: Tokens.Ring.todaySelectedRim)
            .strokeBorder(Palette.onAccent, lineWidth: Tokens.Ring.todaySelectedInner)
        } else {
          Circle()
            .strokeBorder(
              accent,
              lineWidth: isHighContrast ? Tokens.Ring.selectedHighContrast : Tokens.Ring.selected)
        }
      }
    }
  }

  private func fill(isPressed: Bool) -> Color {
    if day.isToday { return accent }
    if isPressed { return Palette.pressedFill }
    if isHovered { return Palette.hoverFill }
    return .clear
  }

  private var textColor: Color {
    if day.isToday { return Palette.onAccent }
    // Red means a day off, whichever rule made it one. Dimming weekends instead, as this did at
    // first, reads as the opposite of highlighting them, and on glass as nothing at all.
    if day.holidayName != nil || (day.isWeekend && highlightsWeekends) {
      return Palette.dayOff.opacity(day.isInCurrentMonth ? 1 : Tokens.Opacity.dayOffInAdjacentMonth)
    }
    if !day.isInCurrentMonth { return isHighContrast ? Palette.secondary : Palette.tertiary }
    return Palette.primary
  }
}

/// The today circle swells and settles when the user comes back to today. Nothing moves under
/// Reduce Motion.
private struct TodayPulse: ViewModifier {
  let trigger: Int

  func body(content: Content) -> some View {
    if trigger == 0 || Motion.isReduced {
      content
    } else {
      content.phaseAnimator([1, Tokens.Scale.todayPulse, 1], trigger: trigger) { view, scale in
        view.scaleEffect(scale)
      } animation: { _ in
        Motion.todayPulse
      }
    }
  }
}

/// The green capsule behind a run of vacation days. Its ends are the same circle the day is
/// drawn in, so one day of vacation is a green circle and a week is that circle stretched.
/// A middle piece and the joined side of an end piece reach across the column spacing, so
/// the run reads as one band and not as beads.
private struct VacationBand: View {
  let segment: BandSegment
  let columnSpacing: CGFloat
  let isDark: Bool

  var body: some View {
    GeometryReader { geometry in
      // Only the trailing side reaches across the spacing, the whole of it, so two neighbours
      // never paint the same pixels and the tint stays even along the band.
      let leadingJoined = segment == .middle || segment == .end
      let trailingJoined = segment == .middle || segment == .start
      let x0: CGFloat = 0
      let x1 = geometry.size.width + (trailingJoined ? columnSpacing : 0)
      let line = Tokens.Ring.vacationBand
      ZStack {
        BandShape(leadingJoined: leadingJoined, trailingJoined: trailingJoined, closed: true)
          .fill(Palette.vacation.opacity(isDark ? Tokens.Opacity.vacationFillDark : Tokens.Opacity.vacationFillLight))
        // Only the long edges and the rounded ends are stroked: a line across a joined side
        // would show as a seam between two days of one vacation.
        BandShape(leadingJoined: leadingJoined, trailingJoined: trailingJoined, closed: false)
          .inset(by: line / 2)
          .stroke(Palette.vacation.opacity(isDark ? Tokens.Opacity.vacationLineDark : Tokens.Opacity.vacationLineLight), lineWidth: line)
      }
      .frame(width: x1 - x0, height: geometry.size.height)
      .offset(x: x0)
    }
  }
}

/// A capsule whose joined sides are open: square, and without a line when not closed.
private struct BandShape: InsettableShape {
  let leadingJoined: Bool
  let trailingJoined: Bool
  let closed: Bool
  var insetAmount: CGFloat = 0

  func inset(by amount: CGFloat) -> BandShape {
    var copy = self
    copy.insetAmount += amount
    return copy
  }

  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: 0, dy: insetAmount)
    let radius = r.height / 2
    var path = Path()
    // Top edge, left to right, then the trailing end, the bottom edge and the leading end.
    let topStart = CGPoint(x: leadingJoined ? r.minX : r.minX + radius, y: r.minY)
    let topEnd = CGPoint(x: trailingJoined ? r.maxX : r.maxX - radius, y: r.minY)
    path.move(to: topStart)
    path.addLine(to: topEnd)
    if trailingJoined {
      if closed { path.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) } else { path.move(to: CGPoint(x: r.maxX, y: r.maxY)) }
    } else {
      path.addArc(center: CGPoint(x: r.maxX - radius, y: r.midY), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
    }
    let bottomEnd = CGPoint(x: leadingJoined ? r.minX : r.minX + radius, y: r.maxY)
    path.addLine(to: bottomEnd)
    if leadingJoined {
      if closed { path.closeSubpath() }
    } else {
      path.addArc(center: CGPoint(x: r.minX + radius, y: r.midY), radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
      if closed { path.closeSubpath() }
    }
    return path
  }
}
