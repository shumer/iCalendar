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

  private var footer: some View {
    let metrics = model.metrics
    return Text(model.footerText)
      .font(model.typography.footer)
      .foregroundStyle(Palette.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity)
      .frame(height: metrics.footerHeight)
      .background(
        Palette.hoverFill,
        in: RoundedRectangle(cornerRadius: metrics.innerCornerRadius, style: .continuous))
      .contentTransition(.opacity)
      .accessibilityLabel(L("accessibility.selectedDate", model.footerText))
  }
}
