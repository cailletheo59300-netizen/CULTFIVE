import XCTest
@testable import LumiCore

final class ProfileTests: XCTestCase {
    func testLevelsInOrderAndRewards() {
        var profile = Profile()
        XCTAssertEqual(profile.hints, Economy.startingHints)
        XCTAssertEqual(profile.nextLevel, 1)
        for number in 1...4 { XCTAssertTrue(profile.completeLevel(number).firstTime) }
        XCTAssertEqual(profile.hints, Economy.startingHints)
        XCTAssertEqual(profile.completeLevel(5).hints, 1)
        XCTAssertEqual(profile.levelsDone, 5)
        // Rejouer un ancien niveau ne rapporte rien.
        XCTAssertFalse(profile.completeLevel(3).firstTime)
        XCTAssertEqual(profile.levelsDone, 5)
    }

    func testLevelThemeUnlock() {
        var profile = Profile()
        let mint = Catalog.theme("theme.mint")
        XCTAssertFalse(profile.owns(mint))
        profile.levelsDone = 14
        XCTAssertEqual(profile.completeLevel(15).unlockedTheme, "theme.mint")
        XCTAssertTrue(profile.owns(mint))
        profile.select(mint)
        XCTAssertEqual(profile.theme, "theme.mint")
        profile.select(Catalog.theme("theme.neon"))
        XCTAssertEqual(profile.theme, "theme.mint")
    }

    func testDailyStreak() {
        var profile = Profile()
        XCTAssertEqual(profile.completeDaily(day: "2026-10-01", time: 100).streak, 1)
        XCTAssertEqual(profile.completeDaily(day: "2026-10-02", time: 90).streak, 2)
        // Rejouée le même jour : pas de nouvelle récompense, meilleur temps gardé.
        XCTAssertFalse(profile.completeDaily(day: "2026-10-02", time: 80).firstTime)
        XCTAssertEqual(profile.dailyTime, 80)
        XCTAssertEqual(profile.currentStreak(today: "2026-10-03"), 2)
        XCTAssertEqual(profile.currentStreak(today: "2026-10-04"), 0)
        XCTAssertEqual(profile.completeDaily(day: "2026-10-05", time: 70).streak, 1)
        XCTAssertEqual(profile.bestStreak, 2)
    }

    func testSeventhDayBonus() {
        var profile = Profile()
        var day = "2026-10-01"
        var last = Reward()
        for _ in 0..<7 {
            last = profile.completeDaily(day: day, time: 60)
            day = DayKey.key(for: DayKey.date(of: day)!.addingTimeInterval(86_400))
        }
        XCTAssertEqual(last.streak, 7)
        XCTAssertEqual(last.hints, Economy.dailyReward + Economy.streakBonus)
    }

    func testBonusGrid() {
        var profile = Profile()
        let day = "2026-10-10"
        XCTAssertFalse(profile.canUnlockBonus(today: day))
        profile.completeDaily(day: day, time: 50)
        XCTAssertTrue(profile.canUnlockBonus(today: day))
        profile.unlockBonus(today: day)
        XCTAssertTrue(profile.bonusAvailable(today: day))
        XCTAssertFalse(profile.canUnlockBonus(today: day))
        XCTAssertEqual(profile.completeBonus(day: day).hints, Economy.bonusReward)
        XCTAssertFalse(profile.bonusAvailable(today: day))
    }

    func testHintsAndAdCap() {
        var profile = Profile()
        profile.hints = 1
        XCTAssertTrue(profile.useHint())
        XCTAssertFalse(profile.useHint())
        for _ in 0..<Economy.maxAdHintsPerDay {
            XCTAssertTrue(profile.canEarnAdHint(today: "2026-10-10"))
            profile.earnAdHint(today: "2026-10-10")
        }
        XCTAssertFalse(profile.canEarnAdHint(today: "2026-10-10"))
        XCTAssertTrue(profile.canEarnAdHint(today: "2026-10-11"))
        XCTAssertEqual(profile.hints, Economy.maxAdHintsPerDay)
    }

    func testDailyTimePenalty() {
        XCTAssertEqual(Economy.dailyTime(seconds: 95, hintsUsed: 2), 95 + 2 * Economy.hintPenaltySeconds)
    }

    func testSavedGrids() {
        var profile = Profile()
        profile.save(SavedGrid(key: "level-1", marks: [0, 1], elapsed: 3, hintsUsed: 0))
        profile.save(SavedGrid(key: "daily-x", marks: [], elapsed: 1, hintsUsed: 0))
        profile.save(SavedGrid(key: "level-1", marks: [2], elapsed: 9, hintsUsed: 1))
        XCTAssertEqual(profile.saved.count, 2)
        XCTAssertEqual(profile.saved("level-1")?.elapsed, 9)
        profile.save(SavedGrid(key: "a", marks: [], elapsed: 0, hintsUsed: 0))
        profile.save(SavedGrid(key: "b", marks: [], elapsed: 0, hintsUsed: 0))
        XCTAssertEqual(profile.saved.count, 3)
        profile.forget("b")
        XCTAssertNil(profile.saved("b"))
    }

    /// Un profil d'une ancienne version (champs manquants) se lit toujours.
    func testTolerantDecoding() throws {
        let old = #"{"levelsDone": 12, "hints": 7}"#.data(using: .utf8)!
        let profile = try JSONDecoder().decode(Profile.self, from: old)
        XCTAssertEqual(profile.levelsDone, 12)
        XCTAssertEqual(profile.hints, 7)
        XCTAssertTrue(profile.autoCrosses)
        XCTAssertEqual(profile.theme, Catalog.defaultTheme)
        var saved = profile
        saved.save(SavedGrid(key: "level-13", marks: [0, 1, 2], elapsed: 12.5, hintsUsed: 1))
        saved.ownedThemes = ["theme.neon"]
        let again = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(again.levelsDone, 12)
        XCTAssertEqual(again.saved, saved.saved)
        XCTAssertEqual(again.ownedThemes, ["theme.neon"])
    }

    func testAdPacing() {
        let install = Date(timeIntervalSince1970: 0)
        var pacing = AdPacing()
        let later = install.addingTimeInterval(AdPacing.freePeriod + 10)
        for _ in 0..<AdPacing.gridsBetween { pacing.gridStarted(); pacing.gridFinished() }
        XCTAssertFalse(pacing.interstitialDue(now: install.addingTimeInterval(60), firstLaunch: install, noAds: false))
        XCTAssertTrue(pacing.interstitialDue(now: later, firstLaunch: install, noAds: false))
        XCTAssertFalse(pacing.interstitialDue(now: later, firstLaunch: install, noAds: true))
        pacing.rewardedWatched()
        XCTAssertFalse(pacing.interstitialDue(now: later, firstLaunch: install, noAds: false))
        pacing.gridStarted()
        pacing.interstitialShown(now: later)
        XCTAssertFalse(pacing.interstitialDue(now: later.addingTimeInterval(10), firstLaunch: install, noAds: false))
    }

    func testCatalog() {
        XCTAssertEqual(Set(Catalog.themes.map(\.id)).count, Catalog.themes.count)
        for theme in Catalog.themes { XCTAssertGreaterThanOrEqual(theme.zones.count, 9) }
        XCTAssertTrue(StoreProduct.starter.removesAds)
        XCTAssertEqual(StoreProduct.starter.themes.count, 2)
        XCTAssertTrue(StoreProduct.hintsSmall.isConsumable)
        XCTAssertFalse(StoreProduct.starter.isConsumable)
    }
}
