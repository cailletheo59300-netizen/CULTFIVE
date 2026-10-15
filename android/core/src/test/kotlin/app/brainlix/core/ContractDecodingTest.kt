package app.brainlix.core

import kotlinx.serialization.decodeFromString
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

/// Tests de contrat : les mêmes vraies réponses du serveur que l'app iPhone (ios/…/Fixtures, scripts/gen-fixtures.sh).
/// Si le serveur change de forme, ces tests cassent avant l'app.
class ContractDecodingTest {
    private val dir = File(System.getProperty("fixtures") ?: "../../ios/Packages/CultFiveCore/Tests/CultFiveCoreTests/Fixtures")
    private inline fun <reified T> fixture(name: String): T = BrainlixJson.decodeFromString(File(dir, "$name.json").readText())

    @Test fun daily() {
        val status: DailyStatus = fixture("daily_status")
        assertEquals(DailyState.AVAILABLE, status.state)
        val start: DailyStart = fixture("daily_start")
        assertEquals(1, start.nextPosition)

        val response: DailyQuestionResponse = fixture("daily_question")
        val question = assertNotNull(response.question)
        assertFalse(response.expired)
        assertNull(question.reveal, "pas de réponse avant validation")
        assertEquals(1, question.position)

        val verdict: DailyVerdict = fixture("daily_verdict")
        assertEquals(true, verdict.isCorrect)
        assertNotNull(verdict.reveal)

        val result: DailyResult = fixture("daily_result")
        assertEquals(5, result.answers.size)
        assertEquals(Percentile.Source.ESTIMATE, result.percentile?.source)
        assertTrue(result.achievements.isNotEmpty())

        val review: List<ReviewItem> = fixture("daily_review")
        assertEquals(5, review.size)
        assertTrue(review.all { it.question.reveal != null })
        assertTrue(review.any { it.given != null })

        val history: List<DailyHistoryEntry> = fixture("history")
        assertEquals(result.score, history.first().score)
    }

    @Test fun play() {
        val pack: PlayPack = fixture("play_pack")
        assertEquals(6, pack.questions.size)
        for (question in pack.questions) {
            val reveal = assertNotNull(question.reveal)
            assertNotNull(question.conceptId)
            assertNotNull(question.difficulty)
            assertTrue(assertNotNull(question.expected) in 0.0..1.0)
            // Le correcteur local doit accepter la bonne réponse telle que le serveur l'exprime.
            val a = reveal.answer
            val given: GivenAnswer = when (question.type) {
                QuestionType.MCQ, QuestionType.MAP_PICK, QuestionType.IMAGE_CHOICE -> GivenAnswer.Option(assertNotNull(a.optionId))
                QuestionType.TRUE_FALSE -> GivenAnswer.Bool(assertNotNull(a.value.boolValue))
                QuestionType.NUMERIC, QuestionType.COUNTER, QuestionType.TIMELINE, QuestionType.GAUGE -> GivenAnswer.Number(assertNotNull(a.value.doubleValue))
                QuestionType.ORDERING -> GivenAnswer.Order(assertNotNull(a.order))
                QuestionType.PAIRS -> GivenAnswer.Pairs(assertNotNull(a.pairs))
                QuestionType.LETTERS -> GivenAnswer.Text(assertNotNull(a.word))
                QuestionType.WORD_ORDER -> GivenAnswer.Words(assertNotNull(a.words))
                QuestionType.NUMBER_TARGET -> GivenAnswer.Steps(assertNotNull(a.steps))
                QuestionType.MAP_PIN -> GivenAnswer.Pin(assertNotNull(a.lat), assertNotNull(a.lon))
                QuestionType.SORT -> GivenAnswer.Groups(assertNotNull(a.groups))
                QuestionType.UNKNOWN -> fail("type inconnu dans les fixtures")
            }
            assertEquals(true, AnswerEvaluator.isCorrect(given, question), question.prompt)
        }
        val submit: PlaySubmitResult = fixture("play_submit")
        assertEquals(6, submit.recorded)
        assertEquals(6, submit.correct)
        assertTrue(assertNotNull(submit.points) > 6 * 50)
        val ratings = assertNotNull(submit.ratings)
        assertTrue(ratings.isNotEmpty())
        assertTrue(ratings.all { it.delta > 0 && !it.placed })
        assertTrue(submit.results.all { (it.points ?: 0) > 0 })
    }

    @Test fun albumAndSeason() {
        val opening: AlbumOpening = fixture("album_opening")
        assertEquals("history", opening.series)
        assertFalse(opening.gold)
        assertEquals(5, opening.pulls.size)
        assertTrue(opening.pulls.any { it.rarity != "common" }, "au moins une rare")
        val album: AlbumOverview = fixture("album_overview")
        assertFalse(album.admin)
        assertEquals(opening.balance, album.neurones)
        assertTrue("dos.classique" in album.cosmetics)
        assertTrue(album.cards.size >= 5)
        val season: SeasonOverview = fixture("season_overview")
        assertNotNull(season.season)
        assertEquals(season.tiers, season.rewards.size)
        assertEquals(12, season.missions.size)
        assertEquals(season.points / season.tierPoints, season.tier)
        val chest: ChestContents = fixture("chest_gold")
        assertEquals(ChestTier.GOLD, chest.reachedTier)
        assertEquals(1, chest.packTickets)
        assertNotNull(chest.card)
        val none: SeasonOverview = BrainlixJson.decodeFromString("""{"season":null}""")
        assertNull(none.season)
        assertTrue(none.rewards.isEmpty())
    }

    @Test fun questsAndRecap() {
        val quests: QuestsOverview = fixture("quests")
        assertEquals(3, quests.day.quests.size)
        assertEquals(3, quests.week.quests.size)
        assertEquals("Fais le 5 du jour", quests.day.quests.first().label)
        assertTrue(quests.day.endsAt.isNotEmpty())
        assertTrue(quests.day.quests.all { it.progress <= it.target })
        val weeks: List<WeekRecap> = fixture("weekly_recap")
        assertTrue(weeks.isNotEmpty())
        assertTrue(weeks[0].answers > 0)
        assertNotNull(weeks[0].rate)
        val history: List<DailyHistoryEntry> = fixture("history")
        val finished = assertNotNull(history.firstOrNull { it.status != "in_progress" })
        assertEquals((finished.score ?: 0) * 20, finished.rate)
        assertNotNull(finished.percentile)
    }

    @Test fun profileAndStats() {
        val profile: Profile = fixture("profile")
        assertEquals("alice_fx", profile.handle)
        assertTrue(profile.xpTotal > 0)
        val skills: List<SkillSummary> = fixture("skills")
        assertEquals(12, skills.size)
        val stats: DomainStats = fixture("domain_stats")
        assertEquals("geography", stats.domainId)
        assertTrue(stats.subdomains.isNotEmpty())
        assertNotNull(stats.cote)
        assertNotNull(stats.placement)
        assertTrue(skills.all { it.cote != null && it.placed != null })
        assertTrue(stats.subdomains.all { it.cote != null })
        val errors: ErrorsOverview = fixture("errors")
        assertTrue(errors.active.isNotEmpty())
        val achievements: List<AchievementRef> = fixture("achievements")
        assertTrue(achievements.any { it.unlockedAt != null })
        val domains: List<DomainInfo> = fixture("domains")
        assertEquals(12, domains.size)
    }

    @Test fun social() {
        val friends: FriendsOverview = fixture("friends")
        assertEquals("bruno_fx", friends.friends.first().handle)
        val league: LeagueStandings = fixture("league")
        assertEquals("Les Curieux", league.name)
        assertEquals(true, league.standings.first().isMe)
        val leagues: List<LeagueSummary> = fixture("leagues")
        assertEquals(1, leagues.first().members)
    }
}
