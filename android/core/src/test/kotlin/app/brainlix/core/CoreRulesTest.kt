package app.brainlix.core

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.JsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/// Mêmes cas que AnswerEvaluatorTests, RatingTests, NumericEntryTests et ProgressionTests de l'app iPhone.
class AnswerEvaluatorTest {
    private fun number(v: Double) = GivenAnswer.Number(v)
    private fun ans(value: Double, tol: Double) = CorrectAnswer(value = JsonPrimitive(value), tolerance = tol)

    @Test fun mcq() {
        val a = CorrectAnswer(optionId = "b1")
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Option("b1"), QuestionType.MCQ, a))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Option("a1"), QuestionType.MCQ, a))
        assertFalse(AnswerEvaluator.isCorrect(null, QuestionType.MCQ, a))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Bool(true), QuestionType.MCQ, a), "type incohérent ⇒ faux")
    }

    @Test fun trueFalse() {
        val a = CorrectAnswer(value = JsonPrimitive(false))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Bool(false), QuestionType.TRUE_FALSE, a))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Bool(true), QuestionType.TRUE_FALSE, a))
    }

    @Test fun numericWithTolerance() {
        val marathon = ans(42.195, 0.001)
        assertTrue(AnswerEvaluator.isCorrect(number(42.195), QuestionType.NUMERIC, marathon))
        assertTrue(AnswerEvaluator.isCorrect(number(42.196), QuestionType.NUMERIC, marathon))
        assertFalse(AnswerEvaluator.isCorrect(number(42.0), QuestionType.NUMERIC, marathon))
        val exact = ans(102.0, 0.0)
        assertTrue(AnswerEvaluator.isCorrect(number(102.0), QuestionType.NUMERIC, exact))
        assertFalse(AnswerEvaluator.isCorrect(number(102.1), QuestionType.NUMERIC, exact))
    }

    @Test fun orderingAndPairs() {
        val order = CorrectAnswer(order = listOf("x", "y", "z"))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Order(listOf("x", "y", "z")), QuestionType.ORDERING, order))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Order(listOf("y", "x", "z")), QuestionType.ORDERING, order))
        val pairs = CorrectAnswer(pairs = mapOf("l1" to "r1", "l2" to "r2"))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Pairs(mapOf("l2" to "r2", "l1" to "r1")), QuestionType.PAIRS, pairs))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Pairs(mapOf("l1" to "r2", "l2" to "r1")), QuestionType.PAIRS, pairs))
    }

    @Test fun givenAnswerEncodingMatchesServerFormat() {
        assertEquals("""{"option_id":"abc"}""", BrainlixJson.encodeToString<GivenAnswer>(GivenAnswer.Option("abc")))
        val roundTrip = BrainlixJson.decodeFromString<GivenAnswer>(BrainlixJson.encodeToString<GivenAnswer>(GivenAnswer.Pairs(mapOf("a" to "b"))))
        assertEquals(GivenAnswer.Pairs(mapOf("a" to "b")), roundTrip)
        assertEquals(GivenAnswer.Bool(true), BrainlixJson.decodeFromString<GivenAnswer>("""{"value":true}"""))
    }

    @Test fun questionWithSilhouetteDecodes() {
        val json = """{"id":"6f1a2b3c-0000-4000-8000-000000000001","type":"mcq","domain_id":"geography","subdomain_id":"geography.countries","prompt":"Quel pays a cette forme ?","payload":{"options":[{"id":"a","text":"Italie"},{"id":"b","text":"Grèce"}],"shape":{"paths":[[[0.1,0.2],[0.5,0.9],[0.8,0.3]]]}}}"""
        val q = BrainlixJson.decodeFromString<Question>(json)
        assertEquals(3, q.payload.shape?.paths?.first()?.size)
        assertEquals(2, q.payload.options?.size)
    }

    @Test fun marginTypes() {
        val bones = ans(206.0, 10.0)
        assertTrue(AnswerEvaluator.isCorrect(number(214.0), QuestionType.COUNTER, bones))
        assertFalse(AnswerEvaluator.isCorrect(number(217.0), QuestionType.COUNTER, bones))
        assertEquals(AnswerEvaluator.Margin.EXACT, AnswerEvaluator.margin(number(206.0), QuestionType.COUNTER, bones))
        assertEquals(AnswerEvaluator.Margin.WITHIN, AnswerEvaluator.margin(number(214.0), QuestionType.COUNTER, bones))
        assertEquals(AnswerEvaluator.Margin.NEAR, AnswerEvaluator.margin(number(230.0), QuestionType.COUNTER, bones))
        assertEquals(AnswerEvaluator.Margin.MISSED, AnswerEvaluator.margin(number(300.0), QuestionType.COUNTER, bones))
        val rugby = ans(15.0, 0.0)
        assertFalse(AnswerEvaluator.isCorrect(number(14.0), QuestionType.COUNTER, rugby))
        assertEquals(AnswerEvaluator.Margin.NEAR, AnswerEvaluator.margin(number(14.0), QuestionType.COUNTER, rugby))
        assertTrue(AnswerEvaluator.isCorrect(number(-60.0), QuestionType.TIMELINE, ans(-44.0, 20.0)))
        assertTrue(AnswerEvaluator.isCorrect(number(66.0), QuestionType.GAUGE, ans(71.0, 5.0)))
        assertNull(AnswerEvaluator.margin(GivenAnswer.Option("a"), QuestionType.MCQ, CorrectAnswer(optionId = "a")))
    }

    @Test fun lettersAndWords() {
        val word = CorrectAnswer(word = "BAGUETTE")
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Text("baguette"), QuestionType.LETTERS, word))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Text("BAGEUTTE"), QuestionType.LETTERS, word))
        val motto = CorrectAnswer(words = listOf("Tous", "pour", "un", "un", "pour", "tous"))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Words(listOf("Tous", "pour", "un", "un", "pour", "tous")), QuestionType.WORD_ORDER, motto))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Words(listOf("un", "pour", "Tous", "un", "pour", "tous")), QuestionType.WORD_ORDER, motto))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Option("be"), QuestionType.IMAGE_CHOICE, CorrectAnswer(optionId = "be")))
    }

    @Test fun newTypesDecode() {
        val json = """{"id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","type":"word_order","domain_id":"french","subdomain_id":"french.expressions","prompt":"Remets ce proverbe dans l'ordre.","payload":{"tiles":[{"id":"t2","text":"nuit"},{"id":"t1","text":"La"}]},"answer":{"words":["La","nuit"],"sentence":"La nuit."},"explanation":"Mieux vaut dormir avant de décider."}"""
        val q = BrainlixJson.decodeFromString<Question>(json)
        assertEquals(QuestionType.WORD_ORDER, q.type)
        assertEquals(2, q.payload.tiles?.size)
        assertEquals(listOf("La", "nuit"), q.reveal?.answer?.words)
        assertEquals(QuestionType.UNKNOWN, BrainlixJson.decodeFromString<Question>(json.replace("\"word_order\"", "\"hologram\"")).type, "type futur : pas de plantage")
        assertEquals(GivenAnswer.Words(listOf("La", "nuit")), BrainlixJson.decodeFromString<GivenAnswer>("""{"words":["La","nuit"]}"""))
        assertEquals(GivenAnswer.Text("NUIT"), BrainlixJson.decodeFromString<GivenAnswer>("""{"text":"NUIT"}"""))
    }

    @Test fun numberTarget() {
        val steps = listOf(TargetStep(6, "+", 5), TargetStep(11, "-", 2), TargetStep(9, "*", 3))
        assertTrue(AnswerEvaluator.reaches(27, listOf(3, 6, 5, 2), steps))
        assertFalse(AnswerEvaluator.reaches(27, listOf(3, 6, 5, 2), listOf(TargetStep(9, "*", 3))), "9 pas disponible")
        assertFalse(AnswerEvaluator.reaches(36, listOf(3, 6, 5, 2), listOf(TargetStep(6, "*", 6))), "6 une seule fois")
        assertNull(TargetStep(5, "/", 2).result)
        assertNull(TargetStep(2, "-", 5).result)
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Steps(steps), QuestionType.NUMBER_TARGET, CorrectAnswer(numbers = listOf(3, 6, 5, 2), target = 27)))
    }

    @Test fun mapPinAndSort() {
        val strasbourg = CorrectAnswer(lat = 48.58, lon = 7.75, toleranceKm = 60.0)
        val paris = AnswerEvaluator.distanceKm(48.86, 2.35, strasbourg)!!
        assertTrue(kotlin.math.abs(paris - 397) < 10)
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Pin(48.9, 7.6), QuestionType.MAP_PIN, strasbourg))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Pin(47.7, 7.3), QuestionType.MAP_PIN, strasbourg))
        assertEquals(AnswerEvaluator.Margin.EXACT, AnswerEvaluator.margin(GivenAnswer.Pin(48.6, 7.76), QuestionType.MAP_PIN, strasbourg))
        val sorted = CorrectAnswer(groups = mapOf("a" to "x", "b" to "y"))
        assertTrue(AnswerEvaluator.isCorrect(GivenAnswer.Groups(mapOf("b" to "y", "a" to "x")), QuestionType.SORT, sorted))
        assertFalse(AnswerEvaluator.isCorrect(GivenAnswer.Groups(mapOf("a" to "y", "b" to "y")), QuestionType.SORT, sorted))
        assertEquals(GivenAnswer.Option("o1"), BrainlixJson.decodeFromString<GivenAnswer>("""{"option_id":"o1","clues":1}"""))
        assertEquals(QuestionType.UNKNOWN, BrainlixJson.decodeFromString<QuestionType>("\"riddle\""))
        assertEquals(GivenAnswer.Pin(1.5, 2.0), BrainlixJson.decodeFromString<GivenAnswer>("""{"lat":1.5,"lon":2}"""))
    }
}

class RatingTest {
    @Test fun scale() {
        assertEquals(1000, CoteCULT.cote(50.0))
        assertEquals(1400, CoteCULT.cote(73.03))
        assertEquals(600, CoteCULT.cote(26.97))
    }

    @Test fun ranks() {
        assertEquals(CoteCULT.Rank.CURIOUS, CoteCULT.Rank.of(500))
        assertEquals(CoteCULT.Rank.AMATEUR, CoteCULT.Rank.of(600))
        assertEquals(CoteCULT.Rank.AMATEUR, CoteCULT.Rank.of(749))
        assertEquals(CoteCULT.Rank.ENLIGHTENED, CoteCULT.Rank.of(750))
        assertEquals(CoteCULT.Rank.SCHOLAR, CoteCULT.Rank.of(1000))
        assertEquals(CoteCULT.Rank.EXPERT, CoteCULT.Rank.of(1199))
        assertEquals(CoteCULT.Rank.ENCYCLOPEDIA, CoteCULT.Rank.of(1500))
        assertEquals(CoteCULT.Rank.ENCYCLOPEDIA, CoteCULT.Rank.EXPERT.next)
        assertNull(CoteCULT.Rank.ENCYCLOPEDIA.next)
        val next = CoteCULT(975, 80).toNextRank!!
        assertEquals(75, next.second)
        assertTrue(kotlin.math.abs(next.first - 0.5) < 0.001)
    }

    @Test fun placement() {
        assertFalse(CoteCULT(1100, 19).placed)
        assertEquals(1, CoteCULT(1100, 13).placementGames)
        assertTrue(CoteCULT(1100, 20).placed)
        assertEquals(2, CoteCULT(1100, 400).placementGames)
        assertEquals(7, CoteCULT(1100, 7).placementDone)
        assertEquals(13, CoteCULT(1100, 7).placementLeft)
        assertEquals("placement 7/20", CoteCULT(1100, 7).provisionalLabel)
        assertEquals(0, CoteCULT(1100, 400).placementLeft)
        assertTrue(CoteCULT(1100, 3, placed = true).placed, "le serveur fait foi")
    }

    @Test fun globalIsWeighted() {
        val skills = listOf(
            SkillSummary(domainId = "history", name = "Histoire", level = 60, reliability = 0.8, answered = 300, correct = 200, cote = 1200),
            SkillSummary(domainId = "sport", name = "Sport", level = 40, reliability = 0.5, answered = 100, correct = 40, cote = 800),
            SkillSummary(domainId = "music", name = "Musique", level = 50, reliability = 0.0, answered = 0, correct = 0, cote = 1000),
        )
        val global = CoteCULT.global(skills)!!
        assertEquals(1100, global.cote)
        assertEquals(400, global.answered)
        assertNull(CoteCULT.global(listOf(skills[2])))
    }

    @Test fun formatting() {
        assertEquals("+18", CoteCULT.formatDelta(18))
        assertEquals("−7", CoteCULT.formatDelta(-7))
        assertEquals("=", CoteCULT.formatDelta(0))
        assertEquals("1342", CoteCULT.format(1342).filter { it.isDigit() })
    }

    @Test fun relativeDifficulty() {
        assertEquals(RelativeDifficulty.EASY, RelativeDifficulty.of(0.8))
        assertEquals(RelativeDifficulty.MEDIUM, RelativeDifficulty.of(0.55))
        assertEquals(RelativeDifficulty.HARD, RelativeDifficulty.of(0.4))
        assertEquals(RelativeDifficulty.VERY_HARD, RelativeDifficulty.of(0.2))
    }

    @Test fun pointsMatchServer() {
        assertEquals(100, GamePoints.points(true, 0.5, 500))
        assertTrue(GamePoints.points(true, 0.5, 800) > 100)
        assertEquals(0, GamePoints.points(false, 0.1, 2000))
        assertEquals(120, GamePoints.points(true, 0.3, 20000))
    }

    @Test fun adaptiveOrder() {
        fun q(p: Double) = Question("id$p", QuestionType.MCQ, "history", "history.modern", "?", expected = p)
        val remaining = listOf(q(0.6), q(0.3), q(0.85))
        assertEquals(0, AdaptiveOrder.nextIndex(remaining, 0, 0))
        assertEquals(1, AdaptiveOrder.nextIndex(remaining, 3, 0))
        assertEquals(2, AdaptiveOrder.nextIndex(remaining, 0, 2))
    }
}

class NumericEntryTest {
    @Test fun digitsAndGrouping() {
        var e = NumericEntry()
        listOf(3, 6, 0, 0).forEach { e = e.appendDigit(it) }
        assertEquals(3600.0, e.value)
        assertEquals("3 600", e.display(groupingSeparator = " "))
    }

    @Test fun noLeadingZeros() {
        var e = NumericEntry()
        listOf(0, 0, 7).forEach { e = e.appendDigit(it) }
        assertEquals("7", e.display())
    }

    @Test fun decimalSeparator() {
        var e = NumericEntry(maxDecimals = 3).appendDecimalSeparator()
        assertEquals("0,", e.display())
        listOf(1, 2, 5, 9).forEach { e = e.appendDigit(it) }
        assertEquals("0,125", e.display(), "3 décimales maximum")
        e = e.appendDecimalSeparator()
        assertEquals(0.125, e.value)
    }

    @Test fun backspaceAndSign() {
        var e = NumericEntry(allowNegative = true).appendDigit(4).toggleSign()
        assertEquals(-4.0, e.value)
        assertEquals("−4", e.display())
        e = e.backspace()
        assertNull(e.value)
        e = e.backspace()
        assertFalse(e.isNegative)
    }

    @Test fun signDisabledWhenNotAllowed() {
        assertEquals(1.0, NumericEntry(allowNegative = false).appendDigit(1).toggleSign().value)
    }

    @Test fun maxDigits() {
        var e = NumericEntry(maxDigits = 3)
        listOf(1, 2, 3, 4).forEach { e = e.appendDigit(it) }
        assertEquals(123.0, e.value)
    }
}

class ProgressionTest {
    @Test fun xpLevels() {
        assertEquals(1, XPLevel.of(0).level)
        assertEquals(1, XPLevel.of(99).level)
        assertEquals(2, XPLevel.of(100).level)
        assertEquals(2, XPLevel.of(299).level)
        assertEquals(3, XPLevel.of(300).level)
        assertEquals(5, XPLevel.of(1000).level)
        val mid = XPLevel.of(450)
        assertEquals(3, mid.level)
        assertEquals(150, mid.xpIntoLevel)
        assertEquals(300, mid.xpForNextLevel)
        assertTrue(kotlin.math.abs(mid.progress - 0.5) < 0.0001)
    }

    @Test fun reliabilityWords() {
        assertEquals("à affiner", Reliability.of(0.1).label)
        assertEquals("correcte", Reliability.of(0.5).label)
        assertEquals("solide", Reliability.of(0.9).label)
    }

    @Test fun durations() {
        assertEquals("01:43", DurationFormat.clock(103_400))
        assertEquals("1:02:03", DurationFormat.clock(3_723_000))
        assertEquals("3 h 12", DurationFormat.countdown(3 * 3600 + 12 * 60))
        assertEquals("1 min", DurationFormat.countdown(20))
    }

    @Test fun stopwatchIsMonotonicAndPausable() {
        var t = 0L
        val watch = Stopwatch { t }
        watch.start()
        t += 50_000_000
        watch.pause()
        assertEquals(50, watch.elapsedMilliseconds)
        t += 50_000_000
        assertEquals(50, watch.elapsedMilliseconds, "rien ne s'accumule en pause")
    }
}
