import Foundation

/// Demande de note App Store (D-077) : la fenêtre officielle d'Apple (étoiles), une seule fois de notre part, à un
/// joueur actif au moins 3 jours différents, juste après un bon moment (5 du jour à 4 ou 5, record de Survie).
/// Apple décide ensuite de l'afficher ou non (3 fois par an au plus).
enum ReviewPrompt {
    private static let defaults = UserDefaults.standard
    private static let daysKey = "review.activeDays"
    private static let lastDayKey = "review.lastActiveDay"
    private static let askedKey = "review.asked"
    static let minimumDays = 3

    /// Un jour où le joueur a joué : compté une fois par jour.
    static func noteActiveDay(_ date: Date = Date()) {
        let day = Self.day(date)
        guard defaults.string(forKey: lastDayKey) != day else { return }
        defaults.set(day, forKey: lastDayKey)
        defaults.set(defaults.integer(forKey: daysKey) + 1, forKey: daysKey)
    }

    /// La demande peut être faite maintenant (bon moment à vérifier par l'appelant).
    static var isDue: Bool {
        !defaults.bool(forKey: askedKey) && defaults.integer(forKey: daysKey) >= minimumDays
    }

    static func markAsked() { defaults.set(true, forKey: askedKey) }

    private static func day(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
