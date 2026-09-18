import MenuCalCore
import SwiftUI

/// The weekday row and the 6 by 7 grid. The grid slides in the direction of the navigation; the
/// weekday row stays where it is.
struct MonthGridView: View {
  let model: CalendarViewModel

  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    let metrics = model.metrics
    VStack(spacing: metrics.sectionSpacing) {
      weekdayRow
      ZStack {
        weeks(model.grid)
          .id(model.grid.referenceDate)
          .transition(monthTransition)
      }
      .frame(height: metrics.gridHeight)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(model.grid.monthTitle)
  }

  private var weekdayRow: some View {
    let metrics = model.metrics
    return HStack(spacing: metrics.gridColumnSpacing) {
      if model.preferences.showsWeekNumbers {
        Color.clear.frame(width: metrics.weekNumberColumnWidth)
      }
      ForEach(Array(model.grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
        Text(symbol.short)
          .font(model.typography.weekday)
          .foregroundStyle(
            symbol.isWeekend && model.preferences.highlightsWeekends
              ? Palette.dayOff : Palette.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(width: metrics.dayCellSize)
          .accessibilityLabel(symbol.full)
      }
    }
    .frame(height: metrics.weekdayRowHeight)
    .accessibilityHidden(true)
  }

  private func weeks(_ grid: MonthGrid) -> some View {
    let metrics = model.metrics
    return VStack(spacing: metrics.gridRowSpacing) {
      ForEach(grid.weeks) { week in
        HStack(spacing: metrics.gridColumnSpacing) {
          if model.preferences.showsWeekNumbers {
            Text(week.weekNumber)
              .font(model.typography.weekNumber)
              .foregroundStyle(Palette.tertiary)
              .frame(width: metrics.weekNumberColumnWidth)
              .accessibilityLabel(L("accessibility.week", week.weekOfYear))
          }
          ForEach(week.days) { day in
            DayCell(day: day, model: model)
          }
        }
        .accessibilityElement(children: .contain)
      }
    }
  }

  /// Forward moves left, in the reading direction; right to left layouts mirror it.
  private var monthTransition: AnyTransition {
    if Motion.isReduced { return .opacity }
    let reading: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
    let sign: CGFloat
    switch model.state.lastDirection {
    case .forward: sign = reading
    case .backward: sign = -reading
    case .none: return .opacity
    }
    let distance = Motion.slideDistance * sign
    return .asymmetric(
      insertion: .offset(x: distance).combined(with: .opacity),
      removal: .offset(x: -distance).combined(with: .opacity))
  }
}
