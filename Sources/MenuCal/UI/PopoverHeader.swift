import SwiftUI

/// The month and year on the leading side, and one capsule with the three navigation controls
/// on the trailing side.
struct PopoverHeader: View {
  let model: CalendarViewModel

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(model.grid.monthName)
          .font(model.typography.month)
          .foregroundStyle(Palette.primary)
        Text(model.grid.yearText)
          .font(model.typography.year)
          .foregroundStyle(Palette.secondary)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .contentTransition(.opacity)
      .padding(.leading, metrics.headerLeadingInset)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(model.grid.monthTitle)
      .accessibilityAddTraits(.isHeader)

      Spacer(minLength: 8)

      HStack(spacing: 0) {
        navButton(.previous, label: L("navigation.previousMonth")) {
          model.showPreviousMonth()
        } content: {
          Image(systemName: "chevron.backward").font(model.typography.chevron)
        }
        .frame(width: metrics.navButtonSize.width)

        navButton(.today, label: L("navigation.today"), isDisabled: model.isShowingCurrentMonth) {
          model.goToToday()
        } content: {
          Text(L("navigation.today"))
            .font(model.typography.todayButton)
            .padding(.horizontal, metrics.todayButtonHorizontalPadding)
        }

        navButton(.next, label: L("navigation.nextMonth")) {
          model.showNextMonth()
        } content: {
          Image(systemName: "chevron.forward").font(model.typography.chevron)
        }
        .frame(width: metrics.navButtonSize.width)
      }
      .padding(metrics.navCapsulePadding)
      .frame(height: metrics.navCapsuleHeight)
      .background(Palette.hoverFill, in: Capsule())
    }
    .frame(height: metrics.headerHeight)
  }

  private func navButton(
    _ control: CalendarViewModel.Control,
    label: String,
    isDisabled: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder content: () -> some View
  ) -> some View {
    Button(action: action) {
      content()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(NavButtonStyle(isHovered: model.hoveredControl == control && !isDisabled))
    .disabled(isDisabled)
    .focusable(false)
    .onHover { model.hover(control, isInside: $0) }
    .accessibilityLabel(label)
    .help(label)
  }
}

private struct NavButtonStyle: ButtonStyle {
  let isHovered: Bool

  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(isEnabled ? Palette.primary : Palette.tertiary)
      .background(
        configuration.isPressed ? Palette.pressedFill : (isHovered ? Palette.hoverFill : .clear),
        in: Capsule())
      .contentShape(Capsule())
      .animation(Motion.hover, value: configuration.isPressed)
      .animation(Motion.hover, value: isHovered)
  }
}
