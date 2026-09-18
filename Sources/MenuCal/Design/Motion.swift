import AppKit
import SwiftUI

/// DesignSpec section 8. Every animation is a spring, except under Reduce Motion, where
/// everything becomes a short cross fade with no movement.
@MainActor
enum Motion {
  static let slideDistance: CGFloat = 28
  static let panelOpenDuration: TimeInterval = 0.18
  static let panelCloseDuration: TimeInterval = 0.12
  static let panelRise: CGFloat = 6

  static var isReduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  static var monthChange: Animation {
    isReduced ? .easeOut(duration: 0.15) : .spring(response: 0.24, dampingFraction: 0.90)
  }

  static var todayPulse: Animation {
    .spring(response: 0.28, dampingFraction: 0.65)
  }

  static let hover = Animation.easeOut(duration: 0.12)
}
