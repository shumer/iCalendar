import Foundation
import MenuCalCore

func scrollAccumulatorTests(_ run: TestRun) {
  typealias Sample = ScrollAccumulator.Sample

  /// Feeds one trackpad gesture of equal steps and returns the months it produced.
  func gesture(_ accumulator: inout ScrollAccumulator, dx: Double = 0, dy: Double = 0, steps: Int, momentum: Int = 0) -> [Int] {
    var fired: [Int] = []
    for index in 0..<steps {
      let step = accumulator.feed(Sample(deltaX: dx, deltaY: dy, phase: index == 0 ? .began : .changed, timestamp: Double(index) * 0.01))
      if step != 0 { fired.append(step) }
    }
    _ = accumulator.feed(Sample(deltaX: 0, deltaY: 0, phase: .ended, timestamp: 1))
    for index in 0..<momentum {
      let step = accumulator.feed(Sample(deltaX: dx, deltaY: dy, phase: .none, isMomentum: true, timestamp: 1 + Double(index) * 0.01))
      if step != 0 { fired.append(step) }
    }
    return fired
  }

  run.test("a long flick with momentum moves exactly one month") { t in
    var accumulator = ScrollAccumulator()
    t.expectEqual(gesture(&accumulator, dy: -12, steps: 40, momentum: 80), [1])
  }

  run.test("a small nudge moves nothing") { t in
    var accumulator = ScrollAccumulator()
    t.expectEqual(gesture(&accumulator, dy: -3, steps: 10), [])
  }

  run.test("scrolling down goes forward, up goes back") { t in
    var accumulator = ScrollAccumulator()
    t.expectEqual(gesture(&accumulator, dy: -10, steps: 6), [1])
    t.expectEqual(gesture(&accumulator, dy: 10, steps: 6), [-1])
  }

  run.test("each new gesture can move again") { t in
    var accumulator = ScrollAccumulator()
    var total = 0
    for _ in 0..<3 { total += gesture(&accumulator, dy: -10, steps: 6, momentum: 20).reduce(0, +) }
    t.expectEqual(total, 3)
  }

  run.test("a horizontal swipe left goes forward") { t in
    var accumulator = ScrollAccumulator()
    t.expectEqual(gesture(&accumulator, dx: -10, dy: 1, steps: 6), [1])
    t.expectEqual(gesture(&accumulator, dx: 10, dy: -1, steps: 6), [-1])
  }

  run.test("the axis is decided once, early in the gesture") { t in
    var accumulator = ScrollAccumulator()
    var fired: [Int] = []
    // Starts clearly horizontal and then drifts vertically by far more than the threshold.
    fired.append(accumulator.feed(Sample(deltaX: -9, deltaY: 0, phase: .began, timestamp: 0)))
    for index in 1..<10 {
      fired.append(accumulator.feed(Sample(deltaX: 0, deltaY: -20, phase: .changed, timestamp: Double(index) * 0.01)))
    }
    t.expectEqual(fired.filter { $0 != 0 }, [], "vertical drift does not count on a horizontal gesture")
  }

  run.test("a cancelled gesture leaves nothing behind") { t in
    var accumulator = ScrollAccumulator()
    _ = accumulator.feed(Sample(deltaX: 0, deltaY: -35, phase: .began, timestamp: 0))
    _ = accumulator.feed(Sample(deltaX: 0, deltaY: 0, phase: .cancelled, timestamp: 0.1))
    t.expectEqual(gesture(&accumulator, dy: -3, steps: 3), [], "35 points of the old gesture are gone")
  }

  run.test("a wheel without phases steps once per cooldown") { t in
    var accumulator = ScrollAccumulator()
    var fired: [Int] = []
    for index in 0..<10 {
      fired.append(accumulator.feed(Sample(deltaX: 0, deltaY: -1, phase: .none, timestamp: Double(index) * 0.05)))
    }
    t.expectEqual(fired.filter { $0 != 0 }, [1, 1], "ten clicks in half a second are two months")
    t.expectEqual(accumulator.feed(Sample(deltaX: 0, deltaY: 0, phase: .none, timestamp: 9)), 0, "a zero delta is not a click")
    t.expectEqual(accumulator.feed(Sample(deltaX: 0, deltaY: 2, phase: .none, timestamp: 10)), -1)
  }
}
