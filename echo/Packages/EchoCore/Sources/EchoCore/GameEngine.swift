import Foundation

/// Mode de jeu.
public enum GameMode: String, Codable, Sendable {
    /// Parties illimitées, orbes différents à chaque partie.
    case classic
    /// Défi du jour : mêmes orbes pour tout le monde, pas de « Continuer ».
    case daily
}

/// Où en est la partie.
public enum GamePhase: Equatable, Sendable {
    /// La manche attend le premier geste du joueur (rien ne bouge).
    case ready
    /// La manche se joue.
    case playing
    /// Courte pause entre deux manches.
    case transition(remainingTicks: Int)
    /// Le joueur a touché le fantôme de la manche `ghostRound`.
    case dead(ghostRound: Int)
}

/// Ce qui vient de se passer pendant une image (sons, vibrations, effets visuels).
public enum GameEvent: Equatable, Sendable {
    case roundStarted(round: Int)
    case orbCollected(index: Int)
    case roundCleared(round: Int, bonus: Int)
    /// Frôlement ; `multiplier` est le multiplicateur après ce frôlement.
    case nearMiss(ghostRound: Int, multiplier: Int)
    /// Fantôme pâle absorbé ; `points` gagnés, `multiplier` après l'absorption.
    case ghostAbsorbed(ghostRound: Int, points: Int, multiplier: Int)
    /// Le multiplicateur retombe à ×1 (manche finie sans frôlement).
    case multiplierLost
    case died(ghostRound: Int)
}

/// Bilan d'une partie, pour l'écran de fin, les pièces et les classements.
public struct GameResult: Equatable, Sendable {
    public var mode: GameMode
    public var score: Int
    public var roundsCleared: Int
    public var nearMisses: Int
    public var orbs: Int
    public var seconds: Double
    public var continuesUsed: Int
    public var bestMultiplier = 1
}

/// Le moteur du jeu. Il ne connaît ni l'écran ni le temps réel : l'app lui donne les gestes du doigt (`addInput`) et
/// l'appelle 60 fois par seconde (`step`). Tout est déterministe, ce qui le rend testable et rejouable.
///
/// Une manche : le point part du centre, le joueur attrape `orbsPerRound` orbes l'un après l'autre. Ses positions sont
/// enregistrées ; à la manche suivante, elles deviennent un fantôme qui rejoue la manche en même temps que lui.
/// Toucher un fantôme (après son délai d'armement) termine la partie.
public final class GameEngine {
    public let tuning: Tuning
    public let seed: UInt64
    public let mode: GameMode

    public private(set) var phase: GamePhase = .ready
    /// Manche en cours (à partir de 1).
    public private(set) var round = 1
    /// Image de la manche en cours (0 au départ).
    public private(set) var tick = 0
    public private(set) var player: Vec2
    public internal(set) var ghosts: [Ghost] = []
    /// Orbes de la manche en cours et numéro de celui à attraper.
    public private(set) var orbs: [Vec2] = []
    public private(set) var orbIndex = 0

    public private(set) var score = 0
    public private(set) var nearMisses = 0
    public private(set) var orbsCollected = 0
    public private(set) var ghostsAbsorbed = 0
    public private(set) var continuesUsed = 0
    /// Multiplicateur en cours (×1 à ×5) et meilleur atteint dans la partie.
    public internal(set) var multiplier = 1
    public private(set) var bestMultiplier = 1
    private var nearMissesThisRound = 0
    /// Images jouées sur toute la partie (durée).
    public private(set) var totalTicks = 0

    private var recording: [Vec2] = []
    private var pendingInput = Vec2.zero
    /// Fantômes actuellement tout près du joueur : un frôlement compte quand ils s'éloignent sans l'avoir touché.
    private var closeGhosts: Set<Int> = []
    /// Valeurs au début de la manche : « Continuer » rejoue la manche sans compter deux fois ses points.
    private var roundStart = (score: 0, nearMisses: 0, orbs: 0, multiplier: 1)

    public init(seed: UInt64, mode: GameMode, tuning: Tuning = .standard) {
        self.seed = seed
        self.mode = mode
        self.tuning = tuning
        player = tuning.center
        beginRound()
    }

    // MARK: Lecture

    public var currentOrb: Vec2? { orbIndex < orbs.count ? orbs[orbIndex] : nil }

    /// Position à afficher : la dernière position calculée plus le geste déjà reçu et pas encore appliqué.
    /// Le point paraît ainsi collé au doigt, sans attendre la prochaine image de logique (les collisions, elles,
    /// restent calculées image par image).
    public var displayPlayer: Vec2 {
        guard phase == .playing else { return player }
        let move = pendingInput.limited(to: tuning.maxStepPerTick)
        let r = tuning.playerRadius
        return Vec2(min(max(player.x + move.x, r), tuning.arena.x - r), min(max(player.y + move.y, r), tuning.arena.y - r))
    }
    public var nextOrb: Vec2? { orbIndex + 1 < orbs.count ? orbs[orbIndex + 1] : nil }
    public var isDead: Bool { if case .dead = phase { return true } else { return false } }
    /// Les fantômes peuvent-ils tuer à cette image ?
    public var ghostsArmed: Bool { tick >= tuning.ghostArmTicks }
    public var ghostRate: Double { tuning.ghostRate(round: round) }

    /// Le fantôme vit sa dernière manche : il pâlit, devient inoffensif et peut être absorbé.
    public func isFading(_ ghost: Ghost) -> Bool { round - ghost.round >= tuning.ghostLifetime }
    public var roundsCleared: Int { round - 1 }
    /// « Continuer » possible : partie classique, une seule fois.
    public var canContinue: Bool { isDead && mode == .classic && continuesUsed == 0 }

    public func position(of ghost: Ghost, atTick tick: Int? = nil) -> Vec2 {
        ghost.position(atTick: tick ?? self.tick, rate: ghostRate)
    }

    public var result: GameResult {
        GameResult(mode: mode, score: score, roundsCleared: roundsCleared, nearMisses: nearMisses, orbs: orbsCollected,
                   seconds: Double(totalTicks) / Double(tuning.ticksPerSecond), continuesUsed: continuesUsed,
                   bestMultiplier: bestMultiplier)
    }

    // MARK: Commandes

    /// Mouvement du doigt depuis le dernier appel, en unités de l'arène. Le premier geste lance la manche.
    public func addInput(_ delta: Vec2) {
        switch phase {
        case .ready:
            guard delta.length > 0.5 else { return }
            phase = .playing
            pendingInput = delta.limited(to: tuning.maxPendingInput)
            pendingEvents.append(.roundStarted(round: round))
        case .playing:
            pendingInput = (pendingInput + delta).limited(to: tuning.maxPendingInput)
        case .transition, .dead:
            break
        }
    }

    /// Événements produits hors de `step` (début de manche), rendus au prochain `step`.
    private var pendingEvents: [GameEvent] = []

    /// Avance d'une image (1/60 s). Renvoie ce qui s'est passé.
    @discardableResult
    public func step() -> [GameEvent] {
        var events = pendingEvents
        pendingEvents = []
        switch phase {
        case .ready, .dead:
            break
        case .transition(let remaining):
            if remaining <= 1 { beginRound() } else { phase = .transition(remainingTicks: remaining - 1) }
        case .playing:
            advance(&events)
        }
        return events
    }

    /// Après la mort : le fantôme qui a touché le joueur disparaît pour de bon, et la manche recommence.
    /// Renvoie `false` si ce n'est pas possible (défi du jour, déjà utilisé, pas mort).
    @discardableResult
    public func continueAfterDeath() -> Bool {
        guard canContinue, case .dead(let ghostRound) = phase else { return false }
        ghosts.removeAll { $0.round == ghostRound }
        continuesUsed += 1
        score = roundStart.score
        nearMisses = roundStart.nearMisses
        orbsCollected = roundStart.orbs
        multiplier = roundStart.multiplier
        beginRound()
        return true
    }

    // MARK: Déroulement

    private func beginRound() {
        tick = 0
        player = tuning.center
        recording = [player]
        pendingInput = .zero
        closeGhosts = []
        nearMissesThisRound = 0
        // Les échos s'effacent : au-delà de `ghostLifetime` manches, le fantôme disparaît.
        ghosts.removeAll { round - $0.round > tuning.ghostLifetime }
        orbs = OrbPlan.orbs(seed: seed, round: round, tuning: tuning)
        orbIndex = 0
        roundStart = (score, nearMisses, orbsCollected, multiplier)
        phase = .ready
    }

    private func advance(_ events: inout [GameEvent]) {
        tick += 1
        totalTicks += 1

        // 1. Le joueur se déplace tout de suite de tout le geste reçu (au plus `maxStepPerTick`), sans sortir de l'arène.
        let move = pendingInput.limited(to: tuning.maxStepPerTick)
        pendingInput = .zero
        let from = player
        let r = tuning.playerRadius
        player = Vec2(min(max(player.x + move.x, r), tuning.arena.x - r),
                      min(max(player.y + move.y, r), tuning.arena.y - r))
        if recording.count <= tuning.maxRecordingTicks { recording.append(player) }

        // 2. Fantômes : contact (fin de partie), frôlement (bonus), ou absorption d'un fantôme pâle.
        if ghostsArmed {
            for ghost in ghosts {
                let distance = Geometry.distance(from: position(of: ghost), toSegment: from, player)
                if isFading(ghost) {
                    if distance < tuning.playerRadius + tuning.ghostRadius { absorb(ghost, &events) }
                    continue
                }
                if distance < tuning.hitDistance {
                    phase = .dead(ghostRound: ghost.round)
                    events.append(.died(ghostRound: ghost.round))
                    return
                }
                if distance < tuning.nearMissDistance {
                    closeGhosts.insert(ghost.round)
                } else if closeGhosts.remove(ghost.round) != nil {
                    nearMisses += 1
                    nearMissesThisRound += 1
                    multiplier = min(tuning.maxMultiplier, multiplier + 1)
                    bestMultiplier = max(bestMultiplier, multiplier)
                    score += tuning.nearMissPoints
                    events.append(.nearMiss(ghostRound: ghost.round, multiplier: multiplier))
                }
            }
        }

        // 3. Orbe attrapé ?
        guard let orb = currentOrb,
              Geometry.distance(from: orb, toSegment: from, player) < tuning.pickupDistance else { return }
        events.append(.orbCollected(index: orbIndex))
        orbIndex += 1
        orbsCollected += 1
        score += tuning.orbPoints * multiplier
        if orbIndex >= orbs.count { clearRound(&events) }
    }

    private func absorb(_ ghost: Ghost, _ events: inout [GameEvent]) {
        ghosts.removeAll { $0.round == ghost.round }
        closeGhosts.remove(ghost.round)
        let points = tuning.absorbPoints * multiplier
        score += points
        ghostsAbsorbed += 1
        // Une absorption compte comme un frôlement : le multiplicateur monte et ne retombera pas à la fin de la manche.
        nearMissesThisRound += 1
        multiplier = min(tuning.maxMultiplier, multiplier + 1)
        bestMultiplier = max(bestMultiplier, multiplier)
        events.append(.ghostAbsorbed(ghostRound: ghost.round, points: points, multiplier: multiplier))
    }

    private func clearRound(_ events: inout [GameEvent]) {
        let bonus = (tuning.roundPoints + tuning.speedBonus(ticks: tick)) * multiplier
        score += bonus
        events.append(.roundCleared(round: round, bonus: bonus))
        if nearMissesThisRound == 0 && multiplier > 1 {
            multiplier = 1
            events.append(.multiplierLost)
        }
        ghosts.append(Ghost(round: round, path: recording))
        round += 1
        phase = .transition(remainingTicks: tuning.transitionTicks)
    }
}
