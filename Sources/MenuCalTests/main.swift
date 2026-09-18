import Foundation

let run = TestRun()
refreshScheduleTests(run)
calendarEngineTests(run)
calendarNavigatorTests(run)
calendarStateTests(run)
scrollAccumulatorTests(run)
dateFormattingTests(run)
preferencesTests(run)
localizationTests(run)
exit(run.finish())
