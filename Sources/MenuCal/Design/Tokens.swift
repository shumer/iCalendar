import AppKit
import MenuCalCore
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

  static func metrics(for density: Density) -> Metrics {
    switch density {
    case .regular: .regular
    case .compact: .compact
    }
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

/// DesignSpec section 4. System fonts only.
struct Typography: Equatable, Sendable {
  let monthSize: CGFloat
  let todayButtonSize: CGFloat
  let weekdaySize: CGFloat
  let daySize: CGFloat
  let weekNumberSize: CGFloat
  let footerSize: CGFloat
  let chevronSize: CGFloat

  var month: Font { .system(size: monthSize, weight: .semibold) }
  var year: Font { .system(size: monthSize, weight: .regular) }
  var todayButton: Font { .system(size: todayButtonSize, weight: .medium) }
  var weekday: Font { .system(size: weekdaySize, weight: .semibold) }
  var weekNumber: Font { .system(size: weekNumberSize, weight: .medium).monospacedDigit() }
  var footer: Font { .system(size: footerSize, weight: .medium) }
  var chevron: Font { .system(size: chevronSize, weight: .semibold) }

  func day(isToday: Bool, isSelected: Bool) -> Font {
    let weight: Font.Weight = isToday ? .bold : (isSelected ? .semibold : .regular)
    return .system(size: daySize, weight: weight).monospacedDigit()
  }

  static func typography(for density: Density) -> Typography {
    switch density {
    case .regular:
      Typography(
        monthSize: 17, todayButtonSize: 12, weekdaySize: 11, daySize: 14, weekNumberSize: 10,
        footerSize: 12, chevronSize: 11)
    case .compact:
      Typography(
        monthSize: 15, todayButtonSize: 11, weekdaySize: 10, daySize: 12, weekNumberSize: 9,
        footerSize: 11, chevronSize: 10)
    }
  }
}

/// DesignSpec section 5. Semantic colours only, so light, dark and the accent follow the system.
enum Palette {
  static let primary = Color(nsColor: .labelColor)
  static let secondary = Color(nsColor: .secondaryLabelColor)
  static let tertiary = Color(nsColor: .tertiaryLabelColor)
  static let onAccent = Color.white
  static let hoverFill = Color(nsColor: .quaternarySystemFill)
  static let pressedFill = Color(nsColor: .tertiarySystemFill)
  static let separator = Color(nsColor: .separatorColor)
  static let focus = Color(nsColor: .keyboardFocusIndicatorColor)
}
