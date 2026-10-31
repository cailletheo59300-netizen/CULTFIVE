import Foundation

/// Générateur pseudo-aléatoire déterministe (SplitMix64) : la même graine donne toujours la même suite, sur tous les
/// iPhone et toutes les versions. C'est ce qui rend la grille du jour et les niveaux identiques pour tout le monde.
/// Ne jamais utiliser `Int.random` ni l'ordre d'un `Set` ou d'un `Dictionary` dans le générateur : ils changent.
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

    /// Entier entre 0 (inclus) et `bound` (exclu).
    public mutating func int(_ bound: Int) -> Int {
        precondition(bound > 0)
        return Int(next() % UInt64(bound))
    }

    /// Mélange un tableau (Fisher-Yates), toujours de la même façon pour la même graine.
    public mutating func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            array.swapAt(i, int(i + 1))
        }
    }

    /// Un élément au hasard (le tableau ne doit pas être vide).
    public mutating func pick<T>(_ array: [T]) -> T {
        array[int(array.count)]
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
