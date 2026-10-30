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

    /// Déplacement maximal du point par image. Au-delà, le reste du geste est gardé pour les images suivantes.
    public var maxStepPerTick = 38.0
    /// Geste en attente au maximum : un très grand coup de doigt ne téléporte pas le point.
    public var maxPendingInput = 260.0

    // MARK: Manches

    public var orbsPerRound = 3
    /// Délai pendant lequel les fantômes, au départ de chaque manche, sont transparents et inoffensifs (0,75 s).
    public var ghostArmTicks = 45
    /// Pause entre deux manches (0,75 s).
    public var transitionTicks = 45
    /// Enregistrement d'une manche au maximum (30 s) : au-delà, le fantôme rejoue ces 30 s en aller-retour.
    public var maxRecordingTicks = 1800
    /// À partir de cette manche, les fantômes rejouent un peu plus vite à chaque manche…
    public var speedUpFromRound = 8
    public var speedUpPerRound = 0.06
    /// … jusqu'à cette vitesse au plus (×1,5).
    public var maxGhostRate = 1.5

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
    /// Distance au-delà du contact où un passage compte comme frôlement.
    public var nearMissMargin = 34.0

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

    /// Bonus de rapidité pour une manche finie en `ticks` images.
    public func speedBonus(ticks: Int) -> Int {
        max(0, speedBonusTicks - ticks) / speedBonusStepTicks
    }
}
