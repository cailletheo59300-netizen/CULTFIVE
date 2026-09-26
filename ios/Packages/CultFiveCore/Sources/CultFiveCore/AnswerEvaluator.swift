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
        case (.mcq, .option(let id)), (.mapPick, .option(let id)):
            return id == answer.optionId
        case (.trueFalse, .bool(let value)):
            return answer.value?.boolValue == value
        case (.numeric, .number(let value)):
            guard let expected = answer.value?.doubleValue else { return false }
            let tolerance = answer.tolerance ?? 0
            let diff = abs(NSDecimalNumber(decimal: value).doubleValue - expected)
            return diff <= tolerance + 1e-9
        case (.ordering, .order(let ids)):
            return ids == answer.order
        case (.pairs, .pairs(let map)):
            return map == answer.pairs
        default:
            return false
        }
    }
}
