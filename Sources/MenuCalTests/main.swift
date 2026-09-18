import Foundation

let run = TestRun()
refreshScheduleTests(run)
calendarEngineTests(run)
calendarNavigatorTests(run)
calendarStateTests(run)
scrollAccumulatorTests(run)
dateFormattingTests(run)
preferencesTests(run)
exit(run.finish())
