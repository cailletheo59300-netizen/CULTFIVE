import XCTest
@testable import EchoCore

final class DailyTests: XCTestCase {
    func testDayKeysInUTC() {
        // 30/10/2026 à 23 h 30 UTC : encore le 30 en UTC (déjà le 31 à Paris).
        let date = Date(timeIntervalSince1970: 1_793_403_000)
        XCTAssertEqual(DayKey.key(for: date), "2026-10-30")
        XCTAssertEqual(DayKey.previous("2026-11-01"), "2026-10-31")
        XCTAssertEqual(DayKey.previous("2027-01-01"), "2026-12-31")
        XCTAssertEqual(DayKey.previous("2028-03-01"), "2028-02-29")
    }

    func testDailySeedStable() {
        XCTAssertEqual(DayKey.dailySeed("2026-10-30"), DayKey.dailySeed("2026-10-30"))
        XCTAssertNotEqual(DayKey.dailySeed("2026-10-30"), DayKey.dailySeed("2026-10-31"))
        // Valeur figée : si elle change, le défi du jour ne serait plus le même pour tous les joueurs (versions mêlées).
        XCTAssertEqual(SeededRandom.seed(from: "a"), 0xAF63_DC4C_8601_EC8C)
    }

    func testAttemptsAndExtra() {
        var profile = Profile()
        let day = "2026-10-30"
        XCTAssertEqual(profile.dailyAttemptsLeft(day: day), 1)
        XCTAssertTrue(profile.startDailyAttempt(day: day))
        XCTAssertFalse(profile.startDailyAttempt(day: day))
        XCTAssertTrue(profile.canEarnDailyAttempt(day: day))
        profile.earnDailyAttempt(day: day)
        XCTAssertTrue(profile.startDailyAttempt(day: day))
        profile.earnDailyAttempt(day: day)
        XCTAssertTrue(profile.startDailyAttempt(day: day))
        XCTAssertFalse(profile.canEarnDailyAttempt(day: day), "2 essais en plus au maximum")
        // Le lendemain, tout repart.
        XCTAssertEqual(profile.dailyAttemptsLeft(day: "2026-10-31"), 1)
    }

    func testStreak() {
        var profile = Profile()
        XCTAssertEqual(profile.recordDaily(score: 100, day: "2026-10-28"), 20)
        XCTAssertEqual(profile.recordDaily(score: 150, day: "2026-10-28"), 0, "un seul cadeau par jour")
        XCTAssertEqual(profile.dailyBest, 150)
        XCTAssertEqual(profile.recordDaily(score: 90, day: "2026-10-29"), 40)
        XCTAssertEqual(profile.streak, 2)
        XCTAssertEqual(profile.currentStreak(today: "2026-10-30"), 2, "la série tient jusqu'à la fin du jour suivant")
        XCTAssertEqual(profile.currentStreak(today: "2026-10-31"), 0)
        _ = profile.recordDaily(score: 90, day: "2026-11-02")
        XCTAssertEqual(profile.streak, 1)
        XCTAssertEqual(profile.bestStreak, 2)
        XCTAssertEqual(profile.coins, 20 + 40 + 20)
    }
}

final class ProfileTests: XCTestCase {
    func testBuyAndEquip() {
        var profile = Profile()
        let mint = Catalog.trail("trail.mint")
        XCTAssertFalse(profile.buy(mint), "pas assez de pièces")
        profile.coins = 250
        XCTAssertTrue(profile.buy(mint))
        XCTAssertEqual(profile.coins, 50)
        XCTAssertEqual(profile.equippedTrail, "trail.mint")
        XCTAssertFalse(profile.buy(mint), "déjà possédée")
        let fire = Catalog.trail("trail.fire")
        profile.coins = 100_000
        XCTAssertFalse(profile.buy(fire), "apparence vendue en euros, pas en pièces")
        profile.equip(fire)
        XCTAssertEqual(profile.equippedTrail, "trail.mint", "on n'équipe pas une apparence non possédée")
    }

    func testOldSaveStillLoads() throws {
        let json = #"{"coins": 42, "bestScore": 300}"#.data(using: .utf8)!
        let profile = try JSONDecoder().decode(Profile.self, from: json)
        XCTAssertEqual(profile.coins, 42)
        XCTAssertEqual(profile.bestScore, 300)
        XCTAssertEqual(profile.equippedTrail, Catalog.defaultTrail)
        XCTAssertTrue(profile.soundOn)
    }

    func testRoundTrip() throws {
        var profile = Profile()
        profile.coins = 12
        profile.ownedSkins.insert("trail.gold")
        profile.creditedTransactions = [99]
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: data), profile)
    }

    func testRecordGame() {
        var profile = Profile()
        let result = GameResult(mode: .classic, score: 200, roundsCleared: 6, nearMisses: 2, orbs: 20, seconds: 60, continuesUsed: 0)
        XCTAssertTrue(profile.recordGame(result, coinsEarned: 25))
        XCTAssertFalse(profile.recordGame(result, coinsEarned: 25), "égaler son record n'est pas un record")
        XCTAssertEqual(profile.bestScore, 200)
        XCTAssertEqual(profile.bestRound, 6)
        XCTAssertEqual(profile.gamesPlayed, 2)
        XCTAssertEqual(profile.coins, 50)
        var daily = result
        daily.mode = .daily
        daily.score = 999
        XCTAssertFalse(profile.recordGame(daily, coinsEarned: 1), "le défi du jour a son propre classement")
        XCTAssertEqual(profile.bestScore, 200)
    }

    func testCatalogIsConsistent() {
        let ids = Catalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "identifiants uniques")
        for skin in Catalog.all {
            XCTAssertFalse(skin.colors.isEmpty)
            if skin.kind == .decor { XCTAssertEqual(skin.colors.count, 5, skin.id) }
            for color in skin.colors { XCTAssertTrue(color.hasPrefix("#") && color.count == 7, "\(skin.id) \(color)") }
        }
        for product in StoreProduct.allCases {
            for id in product.skins { XCTAssertNotNil(Catalog.skin(id), id) }
        }
    }

    func testEconomy() {
        let result = GameResult(mode: .classic, score: 200, roundsCleared: 6, nearMisses: 2, orbs: 20, seconds: 60, continuesUsed: 0)
        XCTAssertEqual(Economy.coins(for: result), 25)
        XCTAssertEqual(Economy.streakReward(streak: 1), 20)
        XCTAssertEqual(Economy.streakReward(streak: 30), 140)
    }
}

final class AdPacingTests: XCTestCase {
    private let install = Date(timeIntervalSince1970: 1_000_000)

    func testFirstDayIsAdFree() {
        var pacing = AdPacing()
        for _ in 0..<10 { pacing.gameFinished() }
        XCTAssertFalse(pacing.interstitialDue(now: install.addingTimeInterval(3600), firstLaunch: install, noAds: false))
        XCTAssertTrue(pacing.interstitialDue(now: install.addingTimeInterval(25 * 3600), firstLaunch: install, noAds: false))
    }

    func testEveryThreeGamesAndMinimumGap() {
        var pacing = AdPacing()
        var now = install.addingTimeInterval(2 * 86400)
        pacing.gameFinished()
        pacing.gameFinished()
        XCTAssertFalse(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false))
        pacing.gameFinished()
        XCTAssertTrue(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false))
        pacing.interstitialShown(now: now)
        for _ in 0..<3 { pacing.gameFinished() }
        now = now.addingTimeInterval(30)
        XCTAssertFalse(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false), "90 s au moins entre deux pubs")
        now = now.addingTimeInterval(61)
        XCTAssertTrue(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false))
        XCTAssertFalse(pacing.interstitialDue(now: now, firstLaunch: install, noAds: true), "Sans pub")
    }

    func testNoInterstitialRightAfterRewarded() {
        var pacing = AdPacing()
        let now = install.addingTimeInterval(2 * 86400)
        pacing.gameStarted()
        pacing.rewardedWatched()
        for _ in 0..<3 { pacing.gameFinished() }
        XCTAssertFalse(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false))
        pacing.gameStarted()
        XCTAssertTrue(pacing.interstitialDue(now: now, firstLaunch: install, noAds: false))
    }
}
