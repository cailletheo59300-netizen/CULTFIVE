import Foundation

/// Identité de marque centralisée. Aucun autre fichier Swift ne contient le nom en dur.
/// (Le nom affiché sous l'icône vient de `APP_DISPLAY_NAME` dans ios/Config/App.xcconfig.)
enum Brand {
    static let name = "Brainlix"
    /// Signatures : à utiliser ponctuellement, jamais en slogan permanent.
    static let signature = "Cultive ce que tu sais."
    static let dailySignature = "5 questions. Chaque jour."
    static let onboardingHook = "Et toi, tu sais quoi ?"

    static let dailyName = "5 du jour"
    static let currencySingular = "graine"
    static let currencyPlural = "graines"
    static let mascotName = "Léon"

    static let urlScheme = "brainlix"
    static let inviteBaseURL = URL(string: "https://brainlix.site/i/")!
    static let leagueBaseURL = URL(string: "https://brainlix.site/l/")!
    static let duelBaseURL = URL(string: "https://brainlix.site/d/")!
    static let privacyURL = URL(string: "https://brainlix.site/confidentialite")!
    static let termsURL = URL(string: "https://brainlix.site/conditions")!
    static let supportEmail = "theocaille1234@gmail.com"

    static func inviteURL(code: String) -> URL { inviteBaseURL.appendingPathComponent(code) }
    static func leagueURL(code: String) -> URL { leagueBaseURL.appendingPathComponent(code) }
    static func duelURL(code: String) -> URL { duelBaseURL.appendingPathComponent(code) }

    static func currency(_ amount: Int) -> String {
        "\(amount) \(abs(amount) > 1 ? currencyPlural : currencySingular)"
    }
}
