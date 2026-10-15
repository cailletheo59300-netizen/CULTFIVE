package app.brainlix.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject

// Réponses au décodage particulier (mêmes règles que les `init(from:)` de l'app iPhone).

/// Réponse de `daily_question` : une question, ou `expired` si le délai est dépassé.
@Serializable(with = DailyQuestionResponseSerializer::class)
data class DailyQuestionResponse(val question: Question?, val expired: Boolean)

object DailyQuestionResponseSerializer : KSerializer<DailyQuestionResponse> {
    override val descriptor: SerialDescriptor = JsonObject.serializer().descriptor
    override fun deserialize(decoder: Decoder): DailyQuestionResponse {
        val o = (decoder as JsonDecoder).decodeJsonElement().jsonObject
        return if (o["expired"].boolValue == true) DailyQuestionResponse(null, true)
        else DailyQuestionResponse(Question.fromJson(o), false)
    }
    override fun serialize(encoder: Encoder, value: DailyQuestionResponse) =
        (encoder as JsonEncoder).encodeJsonElement(value.question?.toJson() ?: jsonOf("expired" to true))
}

/// Une question de la revue du 5 du jour : la question à plat, plus la réponse donnée.
@Serializable(with = ReviewItemSerializer::class)
data class ReviewItem(val question: Question, val given: GivenAnswer?, val isCorrect: Boolean, val countedMs: Int?) {
    val id: String get() = question.id
}

object ReviewItemSerializer : KSerializer<ReviewItem> {
    override val descriptor: SerialDescriptor = JsonObject.serializer().descriptor
    override fun deserialize(decoder: Decoder): ReviewItem {
        val o = (decoder as JsonDecoder).decodeJsonElement().jsonObject
        return ReviewItem(
            question = Question.fromJson(o),
            given = o["given"]?.let { runCatching { GivenAnswer.fromJson(it) }.getOrNull() },
            isCorrect = o["is_correct"].boolValue ?: error("is_correct absent"),
            countedMs = o["counted_ms"].doubleValue?.toInt(),
        )
    }
    override fun serialize(encoder: Encoder, value: ReviewItem) {
        val map = value.question.toJson().toMutableMap()
        value.given?.let { map["given"] = it.json }
        map["is_correct"] = JsonPrimitive(value.isCorrect)
        value.countedMs?.let { map["counted_ms"] = JsonPrimitive(it) }
        (encoder as JsonEncoder).encodeJsonElement(JsonObject(map))
    }
}

/// État des pubs du jour : récompenses restantes, série à sauver, pub entre les parties autorisée. Champs absents = 0.
@Serializable
data class AdStatus(
    @SerialName("double_seeds") val doubleSeeds: Int = 0,
    @SerialName("boost_chest") val boostChest: Int = 0,
    @SerialName("free_chest") val freeChest: Int = 0,
    /// Pochettes gratuites restantes aujourd'hui (0 ou 1).
    @SerialName("free_pack") val freePack: Int = 0,
    /// Série perdue récupérable (sa longueur), sinon null.
    @SerialName("streak_rescue") val streakRescue: Int? = null,
    val interstitial: Boolean = false,
    val admin: Boolean = false,
)

/// Un événement d'usage : nom (liste blanche côté serveur) et quelques propriétés courtes.
data class AppEvent(val name: String, val props: Map<String, String> = emptyMap(), val appVersion: String? = null) {
    val json: JsonObject
        get() = JsonObject(buildMap {
            put("name", JsonPrimitive(name))
            put("props", jsonOf(*props.map { it.key to it.value }.toTypedArray()))
            appVersion?.let { put("app_version", JsonPrimitive(it)) }
        })
}

/// Nom d'un coffre pour l'affichage : « Coffre en bois »…
object ChestName {
    fun title(tier: String): String = when (tier) {
        "silver" -> "Coffre en argent"
        "gold" -> "Coffre en or"
        "savant" -> "Coffre Savant"
        else -> "Coffre en bois"
    }
}
