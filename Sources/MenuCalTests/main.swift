import Foundation

let run = TestRun()
refreshScheduleTests(run)
calendarEngineTests(run)
calendarNavigatorTests(run)
dateFormattingTests(run)
exit(run.finish())
