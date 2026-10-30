import Foundation

/// Générateur pseudo-aléatoire déterministe (SplitMix64) : la même graine donne toujours la même suite.
/// C'est ce qui rend le défi du jour identique pour tout le monde, sans serveur.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Nombre entre 0 (inclus) et 1 (exclu).
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Nombre entre `a` et `b`.
    public mutating func between(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * unit()
    }

    /// Mélange plusieurs nombres en une graine (graine du jeu + numéro de manche, par exemple).
    public static func mix(_ values: UInt64...) -> UInt64 {
        var generator = SeededRandom(seed: 0x5EED_EC40)
        var result: UInt64 = 0
        for value in values {
            generator.state ^= value &* 0x9E37_79B9_7F4A_7C15
            result = generator.next()
        }
        return result
    }

    /// Graine tirée d'un texte (FNV-1a 64 bits), stable d'un appareil et d'une version à l'autre.
    /// (`String.hashValue` change à chaque lancement : inutilisable ici.)
    public static func seed(from text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
