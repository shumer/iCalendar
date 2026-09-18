import Foundation
import MenuCalCore

func refreshScheduleTests(_ run: TestRun) {
  run.test("a date only pattern wakes once a day") { t in
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "E d MMM"), .day)
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "EEEE, d MMMM yyyy"), .day)
  }

  run.test("minutes, hours and the day period wake on the minute") { t in
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "d MMM HH:mm"), .minute)
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "h a"), .minute)
  }

  run.test("seconds wake every second") { t in
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "HH:mm:ss"), .second)
  }

  run.test("letters inside quotes are text, not fields") { t in
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "d MMM 'ss'"), .day)
    t.expectEqual(RefreshSchedule.granularity(ofPattern: "'week' w"), .day)
  }

  run.test("the next day fire is the coming midnight") { t in
    let calendar = Fixtures.gregorian()
    let now = Fixtures.date(2026, 9, 18, 21, 30, 12, in: calendar)
    let fire = RefreshSchedule.nextFire(after: now, granularity: .day, calendar: calendar)
    t.expectEqual(fire, Fixtures.date(2026, 9, 19, 0, 0, 0, in: calendar))
  }

  run.test("the next minute fire is the top of the next minute") { t in
    let calendar = Fixtures.gregorian()
    let now = Fixtures.date(2026, 9, 18, 21, 30, 12, in: calendar)
    let fire = RefreshSchedule.nextFire(after: now, granularity: .minute, calendar: calendar)
    t.expectEqual(fire, Fixtures.date(2026, 9, 18, 21, 31, 0, in: calendar))
  }

  run.test("a day that loses an hour to daylight saving still ends at midnight") { t in
    // Poland moves to summer time on 2026-03-29, so that day is 23 hours long.
    let calendar = Fixtures.gregorian()
    let now = Fixtures.date(2026, 3, 29, 1, 15, 0, in: calendar)
    let fire = RefreshSchedule.nextFire(after: now, granularity: .day, calendar: calendar)
    t.expectEqual(fire, Fixtures.date(2026, 3, 30, 0, 0, 0, in: calendar))
    t.expectEqual(fire.timeIntervalSince(calendar.startOfDay(for: now)), 23 * 3600)
  }

  run.test("a fire date is always in the future") { t in
    let calendar = Fixtures.gregorian()
    let midnight = Fixtures.date(2026, 9, 19, 0, 0, 0, in: calendar)
    for granularity in [RefreshGranularity.day, .minute, .second] {
      let fire = RefreshSchedule.nextFire(after: midnight, granularity: granularity, calendar: calendar)
      t.expect(fire > midnight, "\(granularity)")
    }
  }

  run.test("finer granularities tolerate less lateness") { t in
    t.expect(RefreshSchedule.tolerance(for: .second) < RefreshSchedule.tolerance(for: .minute))
    t.expect(RefreshSchedule.tolerance(for: .minute) < RefreshSchedule.tolerance(for: .day))
  }
}
