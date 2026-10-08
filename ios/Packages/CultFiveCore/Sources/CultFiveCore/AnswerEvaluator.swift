import Foundation

/// Miroir exact de `public._evaluate` (SQL). Utilisé en mode Jouer pour un verdict instantané (et hors-ligne).
/// Le serveur recalcule toujours le verdict lors de la synchronisation : c'est lui qui fait foi.
public enum AnswerEvaluator {
    public static func isCorrect(_ given: GivenAnswer?, for question: Question) -> Bool? {
        guard let answer = question.reveal?.answer else { return nil }
        return isCorrect(given, type: question.type, answer: answer)
    }

    public static func isCorrect(_ given: GivenAnswer?, type: QuestionType, answer: CorrectAnswer) -> Bool {
        guard let given else { return false }
        switch (type, given) {
        case (.mcq, .option(let id)), (.mapPick, .option(let id)), (.imageChoice, .option(let id)):
            return id == answer.optionId
        case (.trueFalse, .bool(let value)):
            return answer.value?.boolValue == value
        case (.numeric, .number(let value)), (.counter, .number(let value)), (.timeline, .number(let value)), (.gauge, .number(let value)):
            guard let expected = answer.value?.doubleValue else { return false }
            let tolerance = answer.tolerance ?? 0
            let diff = abs(NSDecimalNumber(decimal: value).doubleValue - expected)
            return diff <= tolerance + 1e-9
        case (.proportion, .number(let value)):
            guard let expected = answer.value?.doubleValue else { return false }
            let diff = abs(NSDecimalNumber(decimal: value).doubleValue - expected)
            return diff <= abs(expected) * (answer.relTolerance ?? 0) + 1e-9
        case (.letters, .text(let text)):
            return text.uppercased() == answer.word
        case (.wordOrder, .words(let words)):
            return words == answer.words
        case (.ordering, .order(let ids)):
            return ids == answer.order
        case (.pairs, .pairs(let map)):
            return map == answer.pairs
        default:
            return false
        }
    }

    /// Verdict détaillé d'un type à marge, pour la correction : « Pile ! », « Juste, dans la marge »,
    /// « Presque… hors de la marge » (moins de trois fois la marge) ou « Raté ». Miroir de `public._is_exact`.
    public enum Margin: Equatable, Sendable {
        case exact, within, near, missed
    }

    public static func margin(_ given: GivenAnswer?, type: QuestionType, answer: CorrectAnswer) -> Margin? {
        guard type.hasMargin, case .number(let decimal)? = given, let expected = answer.value?.doubleValue else { return nil }
        let value = NSDecimalNumber(decimal: decimal).doubleValue
        let diff = abs(value - expected)
        let allowed = type == .proportion ? abs(expected) * (answer.relTolerance ?? 0) : (answer.tolerance ?? 0)
        let exactLimit = type == .proportion ? abs(expected) * 0.01 : 0
        if diff <= exactLimit + 1e-9 { return .exact }
        if diff <= allowed + 1e-9 { return .within }
        // Marge nulle (« nombre exact ») : à 1 près, c'est « presque ».
        if diff <= max(allowed * 3, type == .proportion ? abs(expected) * 0.3 : 1) + 1e-9 { return .near }
        return .missed
    }
}
