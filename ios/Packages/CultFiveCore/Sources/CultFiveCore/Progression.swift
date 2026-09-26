import Foundation

/// Niveau d'XP (activité). Totalement distinct du niveau de connaissance.
/// XP cumulée pour atteindre le niveau L : 50 · L · (L − 1) → L2 = 100, L3 = 300, L4 = 600, L5 = 1 000…
public struct XPLevel: Equatable, Sendable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int

    public var progress: Double {
        xpForNextLevel == 0 ? 0 : Double(xpIntoLevel) / Double(xpForNextLevel)
    }

    public static func threshold(for level: Int) -> Int {
        50 * level * (level - 1)
    }

    public init(totalXP: Int) {
        let xp = max(totalXP, 0)
        // Racine de 50 L² − 50 L − xp = 0
        var level = Int((1 + (1 + 4 * Double(xp) / 50).squareRoot()) / 2)
        while XPLevel.threshold(for: level + 1) <= xp { level += 1 }
        while level > 1 && XPLevel.threshold(for: level) > xp { level -= 1 }
        self.level = max(level, 1)
        let start = XPLevel.threshold(for: self.level)
        self.xpIntoLevel = xp - start
        self.xpForNextLevel = XPLevel.threshold(for: self.level + 1) - start
    }
}

/// Fiabilité statistique d'un niveau de connaissance, traduite en mots (jamais un faux pourcentage de précision).
public enum Reliability: Sendable {
    case refining, fair, solid

    public init(_ value: Double) {
        switch value {
        case ..<0.35: self = .refining
        case ..<0.65: self = .fair
        default: self = .solid
        }
    }

    public var label: String {
        switch self {
        case .refining: return "à affiner"
        case .fair: return "correcte"
        case .solid: return "solide"
        }
    }
}

public enum DurationFormat {
    /// « 01:43 » (mm:ss), ou « 1:02:03 » au-delà d'une heure.
    public static func clock(milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds, 0) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// « 4,2 s » pour un temps moyen.
    public static func seconds(milliseconds: Int) -> String {
        let value = Double(milliseconds) / 1000
        return NumberFormat.display((value * 10).rounded() / 10, decimals: 1) + " s"
    }

    /// « 3 h 12 », « 12 min » — compte à rebours jusqu'au prochain Daily.
    public static func countdown(seconds: Int) -> String {
        let s = max(seconds, 0)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        if hours > 0 { return "\(hours) h \(String(format: "%02d", minutes))" }
        return "\(max(minutes, 1)) min"
    }
}
