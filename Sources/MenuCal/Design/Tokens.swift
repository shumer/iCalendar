import AppKit
import SwiftUI

/// The numbers of docs/DesignSpec.md, section 3. When the two disagree the spec wins.
struct Metrics: Equatable, Sendable {
  let panelCornerRadius: CGFloat
  let panelPadding: CGFloat
  let sectionSpacing: CGFloat
  let headerHeight: CGFloat
  let headerLeadingInset: CGFloat
  let navCapsuleHeight: CGFloat
  let navCapsulePadding: CGFloat
  let navButtonSize: CGSize
  let todayButtonHorizontalPadding: CGFloat
  let weekdayRowHeight: CGFloat
  let dayCellSize: CGFloat
  let gridColumnSpacing: CGFloat
  let gridRowSpacing: CGFloat
  let weekNumberColumnWidth: CGFloat
  let footerHeight: CGFloat

  /// Concentric: the radius of a surface nested in the panel is the panel's minus the padding.
  var innerCornerRadius: CGFloat { panelCornerRadius - panelPadding }

  var gridWidth: CGFloat { dayCellSize * 7 + gridColumnSpacing * 6 }
  var gridHeight: CGFloat { dayCellSize * 6 + gridRowSpacing * 5 }

  func panelSize(showsWeekNumbers: Bool, showsFooter: Bool) -> CGSize {
    var width = panelPadding * 2 + gridWidth
    if showsWeekNumbers { width += weekNumberColumnWidth + gridColumnSpacing }
    var height = panelPadding * 2 + headerHeight + sectionSpacing + weekdayRowHeight
      + sectionSpacing + gridHeight
    if showsFooter { height += sectionSpacing + footerHeight }
    return CGSize(width: width, height: height)
  }

  static let regular = Metrics(
    panelCornerRadius: 24, panelPadding: 12, sectionSpacing: 8, headerHeight: 32,
    headerLeadingInset: 6, navCapsuleHeight: 28, navCapsulePadding: 2,
    navButtonSize: CGSize(width: 28, height: 24), todayButtonHorizontalPadding: 8,
    weekdayRowHeight: 20, dayCellSize: 36, gridColumnSpacing: 4, gridRowSpacing: 2,
    weekNumberColumnWidth: 28, footerHeight: 36)

  static let compact = Metrics(
    panelCornerRadius: 20, panelPadding: 10, sectionSpacing: 6, headerHeight: 28,
    headerLeadingInset: 4, navCapsuleHeight: 24, navCapsulePadding: 2,
    navButtonSize: CGSize(width: 24, height: 20), todayButtonHorizontalPadding: 6,
    weekdayRowHeight: 16, dayCellSize: 30, gridColumnSpacing: 2, gridRowSpacing: 2,
    weekNumberColumnWidth: 24, footerHeight: 30)
}

enum Tokens {
  /// Distance between the menu bar and the panel, and between the panel and a screen edge.
  static let menuBarGap: CGFloat = 6
  static let screenEdgeMargin: CGFloat = 8

  enum MenuBar {
    static var font: NSFont { .monospacedDigitSystemFont(ofSize: 13, weight: .medium) }
    static let iconTextGap: CGFloat = 4
  }

  enum Ring {
    static let selected: CGFloat = 1.5
    static let selectedHighContrast: CGFloat = 2
    static let todaySelectedRim: CGFloat = 2
    static let todaySelectedInner: CGFloat = 1.5
    static let focus: CGFloat = 3
    static let focusOffset: CGFloat = 1
  }

  enum Opacity {
    static let todayInAdjacentMonth: Double = 0.55
  }

  enum Scale {
    static let pressed: CGFloat = 0.94
    static let panelClosed: CGFloat = 0.92
    static let todayPulse: CGFloat = 1.18
  }
}
