import MenuCalCore
import SwiftUI

/// One day of the grid. DesignSpec section 6: today is a filled circle, selected is a ring, so
/// the two differ by shape and weight and not by colour alone.
struct DayCell: View {
  let day: DayCellModel
  let model: CalendarViewModel

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    let isSelected = day.id == model.state.selectedDate
    let isFocused = model.showsFocusRing && day.id == model.state.focusedDate

    Button {
      model.select(day)
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
        metrics: model.metrics,
        typography: model.typography))
    .focusable(false)
    .onHover { model.hover(day.id, isInside: $0) }
    .accessibilityLabel(day.accessibilityLabel)
    .accessibilityValue(day.isToday ? L("accessibility.today") : "")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
  let metrics: Metrics
  let typography: Typography

  func makeBody(configuration: Configuration) -> some View {
    let size = metrics.dayCellSize
    configuration.label
      .font(typography.day(isToday: day.isToday, isSelected: isSelected))
      .foregroundStyle(textColor)
      .frame(width: size, height: size)
      .background {
        background(isPressed: configuration.isPressed)
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
    if !day.isInCurrentMonth { return isHighContrast ? Palette.secondary : Palette.tertiary }
    if day.isWeekend && highlightsWeekends { return Palette.secondary }
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
