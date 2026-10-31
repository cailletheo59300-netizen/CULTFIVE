import Foundation

/// Tous les réglages du jeu au même endroit. Pour changer la sensation de jeu (vitesse, taille, difficulté, points),
/// c'est ici qu'on touche, et nulle part ailleurs. Les valeurs sont expliquées dans `echo/docs/REGLES.md`.
public struct Tuning: Sendable {
    // MARK: Arène

    /// Taille de l'arène en unités logiques (format 10:16). L'écran l'agrandit ou la réduit, sans la déformer :
    /// le défi du jour est le même sur tous les iPhone.
    public var arena = Vec2(1000, 1600)
    /// Images de logique par seconde. La logique avance par pas fixes : un fantôme rejoue exactement la manche.
    public var ticksPerSecond = 60

    // MARK: Tailles

    public var playerRadius = 22.0
    public var ghostRadius = 22.0
    /// Zone de contact réduite (75 %) : un frôlement visuel ne tue pas, le jeu paraît juste.
    public var hitboxFactor = 0.75
    public var orbRadius = 40.0

    // MARK: Déplacement

    /// Déplacement maximal du point par image. Le geste est appliqué tout de suite, sans retard : seul un coup de doigt
    /// extrême est raccourci (le surplus est perdu, jamais gardé pour plus tard, sinon le point « glisse » après le doigt).
    public var maxStepPerTick = 120.0
    /// Geste reçu entre deux images, au maximum.
    public var maxPendingInput = 120.0

    // MARK: Accélération du doigt (comme une souris d'ordinateur)

    /// Vitesse du doigt (unités d'arène par seconde) en dessous de laquelle le point suit exactement le geste…
    public var slowFingerSpeed = 400.0
    /// … et au-dessus de laquelle l'accélération est au maximum.
    public var fastFingerSpeed = 2500.0

    // MARK: Manches

    /// Orbes par manche au départ ; un de plus aux manches `extraOrbRounds`.
    public var orbsPerRound = 3
    public var extraOrbRounds = [12, 20]
    /// Un fantôme vit `ghostLifetime` manches, puis s'efface. Pendant sa dernière manche, il pâlit : il devient
    /// inoffensif et peut être absorbé (bonus). Il y a donc au plus 2 fantômes dangereux + 1 pâle à l'écran.
    public var ghostLifetime = 3
    /// Délai pendant lequel les fantômes, au départ de chaque manche, sont transparents et inoffensifs (0,75 s).
    public var ghostArmTicks = 45
    /// Pause entre deux manches (0,75 s).
    public var transitionTicks = 45
    /// Enregistrement d'une manche au maximum (30 s) : au-delà, le fantôme rejoue ces 30 s en aller-retour.
    public var maxRecordingTicks = 1800
    /// À partir de cette manche, les fantômes rejouent un peu plus vite à chaque manche…
    public var speedUpFromRound = 7
    public var speedUpPerRound = 0.04
    /// … jusqu'à cette vitesse au plus (×1,6).
    public var maxGhostRate = 1.6

    // MARK: Orbes

    /// Distance minimale entre un orbe et le bord.
    public var orbMargin = 90.0
    /// Distance minimale entre deux orbes qui se suivent.
    public var orbMinSpacing = 320.0
    /// Distance minimale entre le centre (départ) et le premier orbe.
    public var orbMinFromCenter = 260.0

    // MARK: Points

    public var orbPoints = 10
    public var roundPoints = 20
    /// Bonus de rapidité : 1 point par tranche de `speedBonusStepTicks` gagnée sous `speedBonusTicks` (6 s → 30 points max).
    public var speedBonusTicks = 360
    public var speedBonusStepTicks = 12
    /// Frôler un fantôme sans le toucher.
    public var nearMissPoints = 5
    /// Absorber un fantôme pâle (multiplié, puis le multiplicateur monte de 1).
    public var absorbPoints = 25
    /// Distance au-delà du contact où un passage compte comme frôlement.
    public var nearMissMargin = 34.0
    /// Multiplicateur : +1 à chaque frôlement (×5 au plus), appliqué aux orbes et à la fin de manche. Il retombe à ×1
    /// quand une manche se termine sans frôlement.
    public var maxMultiplier = 5

    public init() {}

    public static let standard = Tuning()

    public var center: Vec2 { arena * 0.5 }
    /// Distance de contact entre le joueur et un fantôme.
    public var hitDistance: Double { (playerRadius + ghostRadius) * hitboxFactor }
    /// Distance en dessous de laquelle un passage compte comme frôlement.
    public var nearMissDistance: Double { playerRadius + ghostRadius + nearMissMargin }
    /// Distance pour attraper un orbe.
    public var pickupDistance: Double { playerRadius + orbRadius }

    /// Vitesse de rejeu des fantômes pendant la manche `round`.
    public func ghostRate(round: Int) -> Double {
        guard round >= speedUpFromRound else { return 1 }
        return min(maxGhostRate, 1 + Double(round - speedUpFromRound + 1) * speedUpPerRound)
    }

    /// Orbes à attraper pendant la manche `round`.
    public func orbCount(round: Int) -> Int {
        orbsPerRound + extraOrbRounds.filter { round >= $0 }.count
    }

    /// Accélération du doigt : un geste de `distance` unités fait à `speed` unités par seconde déplace le point de
    /// `distance × gain`. `setting` va de 0 (« Précis ») à 1 (« Rapide »).
    /// Doigt lent : gain de base (1 à 1,3) ; doigt rapide : jusqu'à 1,5 à 2,4 fois le geste.
    public func pointerGain(speed: Double, setting: Double) -> Double {
        let s = max(0, min(1, setting))
        let base = 1.0 + 0.3 * s
        let boost = 1.5 + 0.35 * s
        let t = max(0, min(1, (speed - slowFingerSpeed) / (fastFingerSpeed - slowFingerSpeed)))
        // Courbe douce (pas de cassure quand le doigt accélère).
        let smooth = t * t * (3 - 2 * t)
        return base * (1 + (boost - 1) * smooth)
    }

    /// Bonus de rapidité pour une manche finie en `ticks` images.
    public func speedBonus(ticks: Int) -> Int {
        max(0, speedBonusTicks - ticks) / speedBonusStepTicks
    }
}
