import Foundation

/// Turns a stream of scroll events into month steps. A trackpad flick delivers dozens of events
/// and then momentum on top, which without this would run through a year of months.
public struct ScrollAccumulator: Sendable {
  public enum Phase: Sendable {
    case began, changed, ended, cancelled
    /// A classic wheel, which has no gesture phases at all.
    case none
  }

  public struct Sample: Sendable {
    public var deltaX: Double
    public var deltaY: Double
    public var phase: Phase
    public var isMomentum: Bool
    public var timestamp: TimeInterval

    public init(deltaX: Double, deltaY: Double, phase: Phase, isMomentum: Bool = false, timestamp: TimeInterval) {
      self.deltaX = deltaX
      self.deltaY = deltaY
      self.phase = phase
      self.isMomentum = isMomentum
      self.timestamp = timestamp
    }
  }

  private enum Axis { case horizontal, vertical }

  /// Points of travel that make one month.
  public static let threshold = 40.0
  /// Points of travel after which the gesture's axis is decided.
  public static let axisDecision = 8.0
  /// Seconds between two steps of a phaseless wheel.
  public static let wheelCooldown = 0.25

  private var travelX = 0.0
  private var travelY = 0.0
  private var axis: Axis?
  private var hasFired = false
  private var lastWheelFire = -Double.infinity

  public init() {}

  /// Returns the months to move: -1, 0 or 1. Scrolling down or swiping left goes forward; the
  /// view mirrors the horizontal sign in a right to left layout.
  public mutating func feed(_ sample: Sample) -> Int {
    if sample.isMomentum { return 0 }

    switch sample.phase {
    case .none:
      let dominant = abs(sample.deltaY) >= abs(sample.deltaX) ? sample.deltaY : sample.deltaX
      guard dominant != 0, sample.timestamp - lastWheelFire >= Self.wheelCooldown else { return 0 }
      lastWheelFire = sample.timestamp
      return dominant < 0 ? 1 : -1

    case .began:
      reset()
      return accumulate(sample)

    case .changed:
      return accumulate(sample)

    case .ended, .cancelled:
      reset()
      return 0
    }
  }

  private mutating func accumulate(_ sample: Sample) -> Int {
    travelX += sample.deltaX
    travelY += sample.deltaY
    if axis == nil, max(abs(travelX), abs(travelY)) >= Self.axisDecision {
      axis = abs(travelX) > abs(travelY) ? .horizontal : .vertical
    }
    guard !hasFired, let axis else { return 0 }
    let travel = axis == .horizontal ? travelX : travelY
    guard abs(travel) >= Self.threshold else { return 0 }
    // One month per gesture, however far the fingers go.
    hasFired = true
    return travel < 0 ? 1 : -1
  }

  private mutating func reset() {
    travelX = 0
    travelY = 0
    axis = nil
    hasFired = false
  }
}
