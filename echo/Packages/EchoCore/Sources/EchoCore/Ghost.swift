import Foundation

/// Un fantôme : l'enregistrement d'une manche passée, rejoué image par image.
/// Quand l'enregistrement est fini, il repart en arrière, puis en avant, etc. (aller-retour) : il ne disparaît jamais
/// et ne saute jamais d'un endroit à l'autre. Attendre dans un coin ne sert donc à rien.
public struct Ghost: Equatable, Sendable {
    /// Manche enregistrée (1 pour le fantôme de la manche 1, etc.). Sert d'identifiant.
    public let round: Int
    /// Une position par image, en commençant au centre.
    public let path: [Vec2]

    public init(round: Int, path: [Vec2]) {
        self.round = round
        self.path = path
    }

    /// Position à l'image `tick` de la manche en cours, rejouée à la vitesse `rate`.
    public func position(atTick tick: Int, rate: Double = 1) -> Vec2 {
        guard let first = path.first else { return .zero }
        guard path.count > 1 else { return first }
        let last = Double(path.count - 1)
        let period = 2 * last
        var phase = (Double(max(0, tick)) * rate).truncatingRemainder(dividingBy: period)
        if phase > last { phase = period - phase }
        let index = min(Int(phase), path.count - 2)
        let fraction = phase - Double(index)
        let a = path[index]
        let b = path[index + 1]
        return a + (b - a) * fraction
    }
}
