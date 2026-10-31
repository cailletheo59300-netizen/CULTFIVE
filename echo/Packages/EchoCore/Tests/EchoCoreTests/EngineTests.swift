import XCTest
@testable import EchoCore

final class EngineTests: XCTestCase {
    /// Joueur automatique : va droit vers l'orbe à attraper.
    private func steerToOrb(_ engine: GameEngine, speed: Double = 30) {
        guard let orb = engine.currentOrb else { return }
        let toward = orb - engine.player
        engine.addInput(toward.limited(to: speed))
    }

    /// Joue jusqu'à la fin de la manche en cours (ou la mort). Renvoie les événements.
    @discardableResult
    private func playRound(_ engine: GameEngine, maxTicks: Int = 2000) -> [GameEvent] {
        var events: [GameEvent] = []
        let round = engine.round
        for _ in 0..<maxTicks {
            steerToOrb(engine)
            events += engine.step()
            if engine.round != round || engine.isDead { break }
        }
        return events
    }

    func testRoundOneHasNoGhostAndCompletes() {
        let engine = GameEngine(seed: 42, mode: .classic)
        XCTAssertEqual(engine.phase, .ready)
        XCTAssertTrue(engine.ghosts.isEmpty)
        let events = playRound(engine)
        XCTAssertTrue(events.contains(.roundStarted(round: 1)))
        XCTAssertEqual(events.filter { if case .orbCollected = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(engine.round, 2)
        XCTAssertEqual(engine.ghosts.count, 1)
        XCTAssertEqual(engine.ghosts[0].path.first, Tuning.standard.center, "le fantôme part du centre")
        XCTAssertEqual(engine.orbsCollected, 3)
        XCTAssertGreaterThanOrEqual(engine.score, 3 * 10 + 20)
    }

    func testNothingMovesBeforeFirstGesture() {
        let engine = GameEngine(seed: 1, mode: .classic)
        for _ in 0..<100 { engine.step() }
        XCTAssertEqual(engine.tick, 0)
        XCTAssertEqual(engine.player, Tuning.standard.center)
        engine.addInput(Vec2(0.1, 0))
        engine.step()
        XCTAssertEqual(engine.phase, .ready, "un micro-geste ne lance pas la manche")
    }

    func testTransitionThenReadyAtCenter() {
        let engine = GameEngine(seed: 7, mode: .classic)
        playRound(engine)
        guard case .transition = engine.phase else { return XCTFail("pause entre les manches attendue") }
        for _ in 0..<Tuning.standard.transitionTicks { engine.step() }
        XCTAssertEqual(engine.phase, .ready)
        XCTAssertEqual(engine.player, Tuning.standard.center)
        XCTAssertEqual(engine.tick, 0)
    }

    func testPlayerStaysInsideArena() {
        let engine = GameEngine(seed: 3, mode: .classic)
        for _ in 0..<200 {
            engine.addInput(Vec2(-500, -500))
            engine.step()
        }
        let r = Tuning.standard.playerRadius
        XCTAssertEqual(engine.player.x, r, accuracy: 0.001)
        XCTAssertEqual(engine.player.y, r, accuracy: 0.001)
    }

    func testMovementIsCappedPerTickAndNeverLags() {
        let engine = GameEngine(seed: 3, mode: .classic)
        engine.addInput(Vec2(1000, 0))
        engine.step()
        let moved = engine.player.x - Tuning.standard.center.x
        XCTAssertEqual(moved, Tuning.standard.maxStepPerTick, accuracy: 0.001)
        // Le surplus n'est pas gardé : sans nouveau geste, le point ne bouge plus (pas de « glissade »).
        engine.step()
        XCTAssertEqual(engine.player.x - Tuning.standard.center.x, moved, accuracy: 0.001)
    }

    func testDisplayShowsGestureBeforeNextTick() {
        let engine = GameEngine(seed: 3, mode: .classic)
        engine.addInput(Vec2(10, 0))
        engine.step()
        engine.addInput(Vec2(7, 0))
        XCTAssertEqual(engine.displayPlayer.x - engine.player.x, 7, accuracy: 0.001)
        engine.step()
        XCTAssertEqual(engine.displayPlayer, engine.player)
    }

    func testSmallGestureAppliedImmediately() {
        let engine = GameEngine(seed: 3, mode: .classic)
        engine.addInput(Vec2(10, 0))
        engine.addInput(Vec2(15, 0))
        engine.step()
        XCTAssertEqual(engine.player.x - Tuning.standard.center.x, 25, accuracy: 0.001)
    }

    func testGhostsFadeAfterLifetime() {
        let tuning = Tuning.standard
        let engine = GameEngine(seed: 21, mode: .classic)
        let corner = Vec2(25, 25)
        engine.ghosts = [Ghost(round: -2, path: [corner, corner]), Ghost(round: 0, path: [corner, corner])]
        XCTAssertTrue(engine.isFading(engine.ghosts[0]), "dernière manche du fantôme : il pâlit")
        XCTAssertFalse(engine.isFading(engine.ghosts[1]))
        playRound(engine)
        XCTAssertFalse(engine.isDead)
        for _ in 0..<tuning.transitionTicks { engine.step() }
        XCTAssertEqual(engine.round, 2)
        XCTAssertEqual(engine.ghosts.map(\.round), [0, 1], "le fantôme trop ancien s'est effacé")
    }

    func testFadingGhostIsHarmlessAndCanBeAbsorbed() {
        let tuning = Tuning.standard
        let engine = GameEngine(seed: 5, mode: .classic)
        // Fantôme de la manche -2 pendant la manche 1 : sa dernière manche, il est pâle.
        let spot = tuning.center + Vec2(0, 200)
        engine.ghosts = [Ghost(round: -2, path: [spot, spot])]
        XCTAssertTrue(engine.isFading(engine.ghosts[0]))
        engine.addInput(Vec2(1, 0))
        for _ in 0..<(tuning.ghostArmTicks + 2) { engine.step() }
        var events: [GameEvent] = []
        for _ in 0..<12 {
            engine.addInput(Vec2(0, 20))
            events += engine.step()
        }
        XCTAssertFalse(engine.isDead, "un fantôme pâle ne tue pas")
        XCTAssertTrue(engine.ghosts.isEmpty, "il a été absorbé")
        XCTAssertEqual(engine.ghostsAbsorbed, 1)
        XCTAssertEqual(engine.multiplier, 2)
        XCTAssertTrue(events.contains(.ghostAbsorbed(ghostRound: -2, points: tuning.absorbPoints, multiplier: 2)))
    }

    func testMultiplierBoostsPointsThenDropsWithoutNearMiss() {
        let engine = GameEngine(seed: 42, mode: .classic)
        engine.multiplier = 3
        let events = playRound(engine)
        XCTAssertEqual(engine.orbsCollected, 3)
        guard case .roundCleared(_, let bonus)? = events.first(where: { if case .roundCleared = $0 { return true } else { return false } }) else {
            return XCTFail("manche finie attendue")
        }
        XCTAssertEqual(bonus % 3, 0, "fin de manche multipliée")
        XCTAssertEqual(engine.score, 3 * 10 * 3 + bonus)
        XCTAssertEqual(engine.multiplier, 1, "manche sans frôlement : retour à ×1")
        XCTAssertTrue(events.contains(.multiplierLost))
    }

    func testGhostKillsOnlyOnceArmed() {
        let tuning = Tuning.standard
        let engine = GameEngine(seed: 5, mode: .classic)
        // Fantôme immobile juste à droite du centre.
        let spot = tuning.center + Vec2(60, 0)
        engine.ghosts = [Ghost(round: 1, path: [spot, spot])]
        // On fonce dessus tout de suite : le fantôme n'est pas encore armé, on le traverse.
        engine.addInput(Vec2(60, 0))
        engine.step()
        engine.step()
        XCTAssertFalse(engine.isDead)
        // On reste dessus : dès qu'il s'arme, c'est perdu.
        for _ in 0..<tuning.ghostArmTicks {
            engine.step()
            if engine.isDead { break }
        }
        XCTAssertEqual(engine.phase, .dead(ghostRound: 1))
        XCTAssertGreaterThanOrEqual(engine.tick, tuning.ghostArmTicks)
    }

    func testFastMoveCannotTunnelThroughGhost() {
        var tuning = Tuning.standard
        tuning.maxStepPerTick = 400
        tuning.maxPendingInput = 400
        tuning.ghostArmTicks = 0
        let engine = GameEngine(seed: 5, mode: .classic, tuning: tuning)
        let spot = tuning.center + Vec2(150, 0)
        engine.ghosts = [Ghost(round: 1, path: [spot, spot])]
        engine.addInput(Vec2(350, 0)) // saute par-dessus le fantôme en une image
        engine.step()
        XCTAssertTrue(engine.isDead)
    }

    func testNearMissCountsWhenLeavingWithoutContact() {
        var tuning = Tuning.standard
        tuning.ghostArmTicks = 0
        let engine = GameEngine(seed: 9, mode: .classic, tuning: tuning)
        // Fantôme à 60 unités au-dessus de la ligne suivie : pas de contact (33), mais frôlement (< 78).
        let spot = tuning.center + Vec2(200, 60)
        engine.ghosts = [Ghost(round: 1, path: [spot, spot])]
        var events: [GameEvent] = []
        for _ in 0..<30 {
            engine.addInput(Vec2(15, 0))
            events += engine.step()
        }
        XCTAssertFalse(engine.isDead)
        XCTAssertEqual(engine.nearMisses, 1)
        XCTAssertTrue(events.contains(.nearMiss(ghostRound: 1, multiplier: 2)))
        XCTAssertEqual(engine.multiplier, 2)
        XCTAssertEqual(engine.result.bestMultiplier, 2)
    }

    func testContinueRemovesKillerGhostAndReplaysRound() {
        let tuning = Tuning.standard
        let engine = GameEngine(seed: 11, mode: .classic)
        playRound(engine)
        for _ in 0..<tuning.transitionTicks { engine.step() }
        let scoreBefore = engine.score
        let spot = tuning.center + Vec2(0, 30)
        engine.ghosts.append(Ghost(round: 99, path: [spot, spot]))
        engine.addInput(Vec2(0, 1))
        for _ in 0..<(tuning.ghostArmTicks + 5) where !engine.isDead { engine.step() }
        XCTAssertTrue(engine.isDead)
        XCTAssertTrue(engine.canContinue)
        XCTAssertTrue(engine.continueAfterDeath())
        XCTAssertEqual(engine.phase, .ready)
        XCTAssertEqual(engine.round, 2)
        XCTAssertFalse(engine.ghosts.contains { $0.round == 99 })
        XCTAssertEqual(engine.ghosts.count, 1, "le fantôme de la manche 1 reste")
        XCTAssertEqual(engine.score, scoreBefore, "les points de la manche ratée ne comptent pas deux fois")
        XCTAssertFalse(engine.canContinue)
    }

    func testDailyHasNoContinue() {
        let tuning = Tuning.standard
        let engine = GameEngine(seed: 11, mode: .daily)
        let spot = tuning.center
        engine.ghosts = [Ghost(round: 1, path: [spot, spot])]
        engine.addInput(Vec2(1, 0))
        for _ in 0..<(tuning.ghostArmTicks + 5) where !engine.isDead { engine.step() }
        XCTAssertTrue(engine.isDead)
        XCTAssertFalse(engine.canContinue)
        XCTAssertFalse(engine.continueAfterDeath())
    }

    func testSameSeedSameGame() {
        let a = GameEngine(seed: 123, mode: .daily)
        let b = GameEngine(seed: 123, mode: .daily)
        for _ in 0..<4 {
            playRound(a)
            playRound(b)
            for _ in 0..<Tuning.standard.transitionTicks {
                a.step()
                b.step()
            }
        }
        XCTAssertEqual(a.score, b.score)
        XCTAssertEqual(a.round, b.round)
        XCTAssertEqual(a.ghosts, b.ghosts)
    }

    func testResultSummary() {
        let engine = GameEngine(seed: 42, mode: .classic)
        playRound(engine)
        let result = engine.result
        XCTAssertEqual(result.roundsCleared, 1)
        XCTAssertEqual(result.orbs, 3)
        XCTAssertGreaterThan(result.seconds, 0)
        XCTAssertEqual(result.mode, .classic)
    }
}

final class GhostTests: XCTestCase {
    func testPingPongReplay() {
        let ghost = Ghost(round: 1, path: [Vec2(0, 0), Vec2(10, 0), Vec2(20, 0)])
        let xs = (0...6).map { ghost.position(atTick: $0).x }
        XCTAssertEqual(xs, [0, 10, 20, 10, 0, 10, 20])
    }

    func testFasterReplayInterpolates() {
        let ghost = Ghost(round: 1, path: [Vec2(0, 0), Vec2(10, 0), Vec2(20, 0)])
        XCTAssertEqual(ghost.position(atTick: 1, rate: 1.5).x, 15, accuracy: 0.0001)
    }

    func testSinglePointGhostStays() {
        let ghost = Ghost(round: 1, path: [Vec2(5, 5)])
        XCTAssertEqual(ghost.position(atTick: 500), Vec2(5, 5))
    }

    func testGhostRateGrowsThenCaps() {
        let tuning = Tuning.standard
        XCTAssertEqual(tuning.ghostRate(round: 1), 1)
        XCTAssertEqual(tuning.ghostRate(round: tuning.speedUpFromRound - 1), 1)
        XCTAssertGreaterThan(tuning.ghostRate(round: tuning.speedUpFromRound), 1)
        XCTAssertEqual(tuning.ghostRate(round: 100), tuning.maxGhostRate)
    }

    func testOrbCountGrows() {
        let tuning = Tuning.standard
        XCTAssertEqual(tuning.orbCount(round: 1), 3)
        XCTAssertEqual(tuning.orbCount(round: 11), 3)
        XCTAssertEqual(tuning.orbCount(round: 12), 4)
        XCTAssertEqual(tuning.orbCount(round: 20), 5)
        XCTAssertEqual(OrbPlan.orbs(seed: 1, round: 12).count, 4)
    }

    func testPointerGain() {
        let tuning = Tuning.standard
        for setting in [0.0, 0.5, 1.0] {
            let slow = tuning.pointerGain(speed: 100, setting: setting)
            let medium = tuning.pointerGain(speed: 1400, setting: setting)
            let fast = tuning.pointerGain(speed: 5000, setting: setting)
            XCTAssertLessThan(slow, medium)
            XCTAssertLessThan(medium, fast)
        }
        XCTAssertEqual(tuning.pointerGain(speed: 0, setting: 0), 1, accuracy: 0.0001, "Précis, doigt lent : le point suit exactement")
        XCTAssertLessThan(tuning.pointerGain(speed: 5000, setting: 0), tuning.pointerGain(speed: 5000, setting: 1))
    }
}

final class OrbPlanTests: XCTestCase {
    func testDeterministicAndInsideArena() {
        let tuning = Tuning.standard
        for round in 1...30 {
            let a = OrbPlan.orbs(seed: 77, round: round)
            XCTAssertEqual(a, OrbPlan.orbs(seed: 77, round: round))
            XCTAssertEqual(a.count, tuning.orbCount(round: round))
            for orb in a {
                XCTAssertTrue((tuning.orbMargin...(tuning.arena.x - tuning.orbMargin)).contains(orb.x))
                XCTAssertTrue((tuning.orbMargin...(tuning.arena.y - tuning.orbMargin)).contains(orb.y))
            }
            XCTAssertGreaterThanOrEqual(a[0].distance(to: tuning.center), tuning.orbMinFromCenter)
            for i in 1..<a.count {
                XCTAssertGreaterThanOrEqual(a[i].distance(to: a[i - 1]), tuning.orbMinSpacing)
            }
        }
    }

    func testRoundsAndSeedsDiffer() {
        XCTAssertNotEqual(OrbPlan.orbs(seed: 1, round: 1), OrbPlan.orbs(seed: 1, round: 2))
        XCTAssertNotEqual(OrbPlan.orbs(seed: 1, round: 1), OrbPlan.orbs(seed: 2, round: 1))
    }

    func testSegmentDistance() {
        XCTAssertEqual(Geometry.distance(from: Vec2(5, 3), toSegment: Vec2(0, 0), Vec2(10, 0)), 3, accuracy: 0.0001)
        XCTAssertEqual(Geometry.distance(from: Vec2(-4, 3), toSegment: Vec2(0, 0), Vec2(10, 0)), 5, accuracy: 0.0001)
        XCTAssertEqual(Geometry.distance(from: Vec2(3, 4), toSegment: Vec2(0, 0), Vec2(0, 0)), 5, accuracy: 0.0001)
    }
}
