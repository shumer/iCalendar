import SwiftUI

/// The content of the calendar panel. Stage 1 ships the surface only; the calendar arrives with
/// the engine.
struct CalendarPanelView: View {
  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel(L("panel.accessibilityLabel"))
  }
}
