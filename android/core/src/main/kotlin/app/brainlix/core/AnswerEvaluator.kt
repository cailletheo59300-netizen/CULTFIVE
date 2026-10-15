package app.brainlix.core

import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/// Miroir exact de `public._evaluate` (SQL) et de `AnswerEvaluator.swift`. Verdict instantané (et hors ligne) en partie ;
/// le serveur recalcule toujours le verdict à la synchronisation : c'est lui qui fait foi.
object AnswerEvaluator {
    fun isCorrect(given: GivenAnswer?, question: Question): Boolean? {
        val answer = question.reveal?.answer ?: return null
        return isCorrect(given, question.type, answer)
    }

    fun isCorrect(given: GivenAnswer?, type: QuestionType, answer: CorrectAnswer): Boolean {
        given ?: return false
        return when {
            (type == QuestionType.MCQ || type == QuestionType.MAP_PICK || type == QuestionType.IMAGE_CHOICE) && given is GivenAnswer.Option ->
                given.id == answer.optionId
            type == QuestionType.TRUE_FALSE && given is GivenAnswer.Bool -> answer.value.boolValue == given.value
            (type == QuestionType.NUMERIC || type.hasMargin) && given is GivenAnswer.Number -> {
                val expected = answer.value.doubleValue ?: return false
                abs(given.value - expected) <= (answer.tolerance ?: 0.0) + 1e-9
            }
            type == QuestionType.LETTERS && given is GivenAnswer.Text -> given.text.uppercase() == answer.word
            type == QuestionType.WORD_ORDER && given is GivenAnswer.Words -> given.words == answer.words
            type == QuestionType.NUMBER_TARGET && given is GivenAnswer.Steps -> {
                val numbers = answer.numbers ?: return false
                val target = answer.target ?: return false
                reaches(target, numbers, given.steps)
            }
            type == QuestionType.MAP_PIN && given is GivenAnswer.Pin -> {
                val distance = distanceKm(given.lat, given.lon, answer) ?: return false
                val tolerance = answer.toleranceKm ?: return false
                distance <= tolerance
            }
            type == QuestionType.SORT && given is GivenAnswer.Groups -> given.map == answer.groups
            type == QuestionType.ORDERING && given is GivenAnswer.Order -> given.ids == answer.order
            type == QuestionType.PAIRS && given is GivenAnswer.Pairs -> given.map == answer.pairs
            else -> false
        }
    }

    /// Verdict détaillé d'un type à marge : « Pile ! », « Juste, dans la marge », « Presque… » (moins de trois fois la marge)
    /// ou « Raté ». Miroir de `public._is_exact`.
    enum class Margin { EXACT, WITHIN, NEAR, MISSED }

    fun margin(given: GivenAnswer?, type: QuestionType, answer: CorrectAnswer): Margin? {
        if (type == QuestionType.MAP_PIN && given is GivenAnswer.Pin) {
            val distance = distanceKm(given.lat, given.lon, answer)
            val tolerance = answer.toleranceKm
            if (distance != null && tolerance != null) {
                return when {
                    distance <= tolerance / 10 -> Margin.EXACT
                    distance <= tolerance -> Margin.WITHIN
                    distance <= tolerance * 3 -> Margin.NEAR
                    else -> Margin.MISSED
                }
            }
        }
        if (!type.hasMargin || given !is GivenAnswer.Number) return null
        val expected = answer.value.doubleValue ?: return null
        val diff = abs(given.value - expected)
        val allowed = answer.tolerance ?: 0.0
        return when {
            diff <= 1e-9 -> Margin.EXACT
            diff <= allowed + 1e-9 -> Margin.WITHIN
            // Marge nulle (« nombre exact ») : à 1 près, c'est « presque ».
            diff <= max(allowed * 3, 1.0) + 1e-9 -> Margin.NEAR
            else -> Margin.MISSED
        }
    }

    /// Le compte est bon : chaque étape utilise deux nombres encore disponibles ; juste si la cible apparaît.
    fun reaches(target: Int, numbers: List<Int>, steps: List<TargetStep>): Boolean {
        val pool = numbers.toMutableList()
        for (step in steps) {
            if (!pool.remove(step.a)) return false
            if (!pool.remove(step.b)) return false
            pool.add(step.result ?: return false)
        }
        return target in pool
    }

    /// Distance à vol d'oiseau (km) entre l'épingle et le bon point. Miroir de `public._km`.
    fun distanceKm(lat: Double, lon: Double, answer: CorrectAnswer): Double? {
        val lat2 = answer.lat ?: return null
        val lon2 = answer.lon ?: return null
        val rad = Math.PI / 180
        val dLat = (lat2 - lat) * rad
        val dLon = (lon2 - lon) * rad
        val h = sin(dLat / 2).pow(2) + cos(lat * rad) * cos(lat2 * rad) * sin(dLon / 2).pow(2)
        return 2 * 6371 * asin(min(1.0, sqrt(h)))
    }
}
