import XCTest
@testable import CultFiveCore

final class ProgressionTests: XCTestCase {
    func testXPLevels() {
        XCTAssertEqual(XPLevel(totalXP: 0).level, 1)
        XCTAssertEqual(XPLevel(totalXP: 99).level, 1)
        XCTAssertEqual(XPLevel(totalXP: 100).level, 2)
        XCTAssertEqual(XPLevel(totalXP: 299).level, 2)
        XCTAssertEqual(XPLevel(totalXP: 300).level, 3)
        XCTAssertEqual(XPLevel(totalXP: 1000).level, 5)
        let mid = XPLevel(totalXP: 450)
        XCTAssertEqual(mid.level, 3)
        XCTAssertEqual(mid.xpIntoLevel, 150)
        XCTAssertEqual(mid.xpForNextLevel, 300)
        XCTAssertEqual(mid.progress, 0.5, accuracy: 0.0001)
    }

    func testReliabilityWords() {
        XCTAssertEqual(Reliability(0.1).label, "à affiner")
        XCTAssertEqual(Reliability(0.5).label, "correcte")
        XCTAssertEqual(Reliability(0.9).label, "solide")
    }

    func testDurations() {
        XCTAssertEqual(DurationFormat.clock(milliseconds: 103_400), "01:43")
        XCTAssertEqual(DurationFormat.clock(milliseconds: 3_723_000), "1:02:03")
        XCTAssertEqual(DurationFormat.countdown(seconds: 3 * 3600 + 12 * 60), "3 h 12")
        XCTAssertEqual(DurationFormat.countdown(seconds: 20), "1 min")
    }

    func testStopwatchIsMonotonicAndPausable() async throws {
        var watch = Stopwatch()
        watch.start()
        try await Task.sleep(nanoseconds: 50_000_000)
        watch.pause()
        let paused = watch.elapsedMilliseconds
        XCTAssertGreaterThanOrEqual(paused, 40)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(watch.elapsedMilliseconds, paused, "rien ne s'accumule en pause")
    }
}
