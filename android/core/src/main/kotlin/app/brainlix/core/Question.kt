package app.brainlix.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject

/// Types de questions. Un type inconnu de cette version (ajouté plus tard côté serveur) devient `UNKNOWN` :
/// affiché comme indisponible, jamais un plantage (même règle que l'app iPhone).
@Serializable(with = QuestionTypeSerializer::class)
enum class QuestionType(val raw: String) {
    MCQ("mcq"), TRUE_FALSE("true_false"), NUMERIC("numeric"), ORDERING("ordering"), PAIRS("pairs"), MAP_PICK("map_pick"),
    // Nouveaux types (serveur 0038) : marge annoncée avant de répondre, ou jeu de lettres, de mots ou d'images.
    COUNTER("counter"), TIMELINE("timeline"), GAUGE("gauge"), LETTERS("letters"), WORD_ORDER("word_order"), IMAGE_CHOICE("image_choice"),
    // Lot 2 (serveur 0040) : le compte est bon, épingle sur la carte, tri.
    NUMBER_TARGET("number_target"), MAP_PIN("map_pin"), SORT("sort"),
    UNKNOWN("unknown");

    /// Types où l'on vise un nombre avec une marge annoncée (« Pile ! / Juste, dans la marge / Presque… / Raté »).
    val hasMargin: Boolean get() = this == COUNTER || this == TIMELINE || this == GAUGE

    companion object {
        fun from(raw: String): QuestionType = entries.firstOrNull { it.raw == raw } ?: UNKNOWN
    }
}

object QuestionTypeSerializer : KSerializer<QuestionType> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("QuestionType", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder) = QuestionType.from(decoder.decodeString())
    override fun serialize(encoder: Encoder, value: QuestionType) = encoder.encodeString(value.raw)
}

/// Élément affichable d'une question (option, élément à classer, membre d'une paire, point sur la carte).
@Serializable
data class Choice(
    val id: String,
    val text: String? = null,
    val lat: Double? = null,
    val lon: Double? = null,
    /// Choix d'images : code pays (drapeau) ou adresse de l'image (tableau).
    val flag: String? = null,
    val image: String? = null,
)

/// Groupe d'un tri : panier (« Mammifère ») ou époque (« Moyen Âge », 476 – 1492).
@Serializable
data class SortGroup(val id: String, val label: String, val sub: String? = null)

/// Une étape du « compte est bon » : a op b (op : +, -, *, /).
@Serializable
data class TargetStep(val a: Int, val op: String, val b: Int) {
    /// Résultat, ou null si l'opération est interdite (division non entière, résultat négatif).
    val result: Int?
        get() = when (op) {
            "+" -> a + b
            "-" -> if (a - b >= 0) a - b else null
            "*" -> a * b
            "/" -> if (b != 0 && a % b == 0) a / b else null
            else -> null
        }

    val symbol: String get() = mapOf("+" to "+", "-" to "−", "*" to "×", "/" to "÷")[op] ?: op
}

/// Silhouette d'un pays : contours normalisés dans [0, 1] (x vers la droite, y vers le bas).
@Serializable
data class CountryShape(val paths: List<List<List<Double>>>)

@Serializable
data class MapRegion(val lat: Double, val lon: Double, val span: Double)

/// Partie publique d'une question : ce que le joueur voit avant de répondre.
@Serializable
data class QuestionPayload(
    val options: List<Choice>? = null,
    val items: List<Choice>? = null,
    val left: List<Choice>? = null,
    val right: List<Choice>? = null,
    val region: MapRegion? = null,
    val unit: String? = null,
    val decimals: Int? = null,
    @SerialName("allow_negative") val allowNegative: Boolean? = null,
    @SerialName("keep_order") val keepOrder: Boolean? = null,
    val shape: CountryShape? = null,
    val min: Double? = null,
    val max: Double? = null,
    val start: Double? = null,
    val tolerance: Double? = null,
    val tiles: List<Choice>? = null,
    val kind: String? = null,
    val numbers: List<Int>? = null,
    val target: Int? = null,
    @SerialName("tolerance_km") val toleranceKm: Double? = null,
    val layout: String? = null,
    val groups: List<SortGroup>? = null,
)

/// Bonne réponse, telle que stockée côté serveur.
@Serializable
data class CorrectAnswer(
    @SerialName("option_id") val optionId: String? = null,
    val value: JsonElement? = null,
    val tolerance: Double? = null,
    val order: List<String>? = null,
    val pairs: Map<String, String>? = null,
    val word: String? = null,
    val display: String? = null,
    val words: List<String>? = null,
    val sentence: String? = null,
    /// Choix d'images : nom de chaque option (pays, tableau), révélé après la réponse.
    val labels: Map<String, String>? = null,
    val numbers: List<Int>? = null,
    val target: Int? = null,
    val steps: List<TargetStep>? = null,
    val solution: List<String>? = null,
    val lat: Double? = null,
    val lon: Double? = null,
    @SerialName("tolerance_km") val toleranceKm: Double? = null,
    val place: String? = null,
    val groups: Map<String, String>? = null,
)

/// Ce qui est révélé après la réponse : bonne réponse, explication, « À retenir ».
@Serializable
data class Reveal(
    val answer: CorrectAnswer,
    val explanation: String,
    val takeaway: String? = null,
    val source: String? = null,
    @SerialName("fact_as_of") val factAsOf: String? = null,
)

/// Une question. La révélation (réponse, explication…) est « à plat » dans le même objet JSON, comme côté serveur.
@Serializable(with = QuestionSerializer::class)
data class Question(
    val id: String,
    val type: QuestionType,
    val domainId: String,
    val subdomainId: String,
    val prompt: String,
    val payload: QuestionPayload = QuestionPayload(),
    val conceptId: String? = null,
    val position: Int? = null,
    val hasHint: Boolean? = null,
    val hasContext: Boolean? = null,
    /// Présente dans les packs Jouer et la revue du 5 du jour ; absente pendant le 5 du jour.
    val reveal: Reveal? = null,
    /// Packs Jouer : difficulté absolue (0–100) et chances de réussite estimées pour ce joueur (0–1).
    val difficulty: Double? = null,
    val expected: Double? = null,
) {
    companion object {
        fun fromJson(o: JsonObject): Question = Question(
            id = o["id"].stringValue ?: error("question sans id"),
            type = QuestionType.from(o["type"].stringValue ?: "unknown"),
            domainId = o["domain_id"].stringValue ?: "",
            subdomainId = o["subdomain_id"].stringValue ?: "",
            prompt = o["prompt"].stringValue ?: "",
            payload = (o["payload"] as? JsonObject)?.let { BrainlixJson.decodeFromJsonElement<QuestionPayload>(it) } ?: QuestionPayload(),
            conceptId = o["concept_id"].stringValue,
            position = o["position"].doubleValue?.toInt(),
            hasHint = o["has_hint"].boolValue,
            hasContext = o["has_context"].boolValue,
            reveal = if (o.containsKey("answer") && o.containsKey("explanation") && o["explanation"] !is kotlinx.serialization.json.JsonNull)
                BrainlixJson.decodeFromJsonElement<Reveal>(o) else null,
            difficulty = o["difficulty"].doubleValue,
            expected = o["expected"].doubleValue,
        )
    }

    fun toJson(): JsonObject {
        val map = linkedMapOf<String, JsonElement>(
            "id" to JsonPrimitive(id), "type" to JsonPrimitive(type.raw), "domain_id" to JsonPrimitive(domainId),
            "subdomain_id" to JsonPrimitive(subdomainId), "prompt" to JsonPrimitive(prompt),
            "payload" to BrainlixJson.encodeToJsonElement(payload),
        )
        conceptId?.let { map["concept_id"] = JsonPrimitive(it) }
        position?.let { map["position"] = JsonPrimitive(it) }
        hasHint?.let { map["has_hint"] = JsonPrimitive(it) }
        hasContext?.let { map["has_context"] = JsonPrimitive(it) }
        difficulty?.let { map["difficulty"] = JsonPrimitive(it) }
        expected?.let { map["expected"] = JsonPrimitive(it) }
        reveal?.let { map.putAll(BrainlixJson.encodeToJsonElement(it).jsonObject) }
        return JsonObject(map)
    }
}

object QuestionSerializer : KSerializer<Question> {
    override val descriptor: SerialDescriptor = JsonObject.serializer().descriptor
    override fun deserialize(decoder: Decoder): Question =
        Question.fromJson((decoder as JsonDecoder).decodeJsonElement().jsonObject)
    override fun serialize(encoder: Encoder, value: Question) = (encoder as JsonEncoder).encodeJsonElement(value.toJson())
}

/// Réponse donnée par le joueur, encodée au format attendu par le serveur.
@Serializable(with = GivenAnswerSerializer::class)
sealed class GivenAnswer {
    data class Option(val id: String) : GivenAnswer()
    data class Bool(val value: Boolean) : GivenAnswer()
    data class Number(val value: Double) : GivenAnswer()
    data class Order(val ids: List<String>) : GivenAnswer()
    data class Pairs(val map: Map<String, String>) : GivenAnswer()
    /// Lettres mélangées : le mot formé.
    data class Text(val text: String) : GivenAnswer()
    /// Mots dans l'ordre : le texte de chaque tuile, dans l'ordre choisi.
    data class Words(val words: List<String>) : GivenAnswer()
    /// Le compte est bon : les opérations faites, dans l'ordre.
    data class Steps(val steps: List<TargetStep>) : GivenAnswer()
    /// Épingle sur la carte.
    data class Pin(val lat: Double, val lon: Double) : GivenAnswer()
    /// Tri : groupe choisi pour chaque étiquette.
    data class Groups(val map: Map<String, String>) : GivenAnswer()

    val json: JsonObject
        get() = when (this) {
            is Option -> jsonOf("option_id" to id)
            is Bool -> jsonOf("value" to value)
            is Number -> jsonOf("value" to value)
            is Order -> jsonOf("order" to ids)
            is Pairs -> jsonOf("pairs" to map)
            is Text -> jsonOf("text" to text)
            is Words -> jsonOf("words" to words)
            is Steps -> jsonOf("steps" to steps.map { mapOf("a" to it.a, "op" to it.op, "b" to it.b) })
            is Pin -> jsonOf("lat" to lat, "lon" to lon)
            is Groups -> jsonOf("groups" to map)
        }

    companion object {
        fun fromJson(json: JsonElement): GivenAnswer? {
            json["option_id"].stringValue?.let { return Option(it) }
            val lat = json["lat"].doubleValue
            val lon = json["lon"].doubleValue
            if (lat != null && lon != null) return Pin(lat, lon)
            (json["steps"] as? JsonArray)?.let { arr ->
                return Steps(arr.mapNotNull { item ->
                    val a = item["a"].doubleValue ?: return@mapNotNull null
                    val op = item["op"].stringValue ?: return@mapNotNull null
                    val b = item["b"].doubleValue ?: return@mapNotNull null
                    TargetStep(a.toInt(), op, b.toInt())
                })
            }
            (json["groups"] as? JsonObject)?.let { m -> return Groups(m.mapNotNull { (k, v) -> v.stringValue?.let { k to it } }.toMap()) }
            json["value"].boolValue?.let { return Bool(it) }
            json["value"].doubleValue?.let { return Number(it) }
            (json["order"] as? JsonArray)?.let { arr -> return Order(arr.mapNotNull { it.stringValue }) }
            (json["pairs"] as? JsonObject)?.let { m -> return Pairs(m.mapNotNull { (k, v) -> v.stringValue?.let { k to it } }.toMap()) }
            json["text"].stringValue?.let { return Text(it) }
            (json["words"] as? JsonArray)?.let { arr -> return Words(arr.mapNotNull { it.stringValue }) }
            return null
        }
    }
}

object GivenAnswerSerializer : KSerializer<GivenAnswer> {
    override val descriptor: SerialDescriptor = JsonObject.serializer().descriptor
    override fun deserialize(decoder: Decoder): GivenAnswer =
        GivenAnswer.fromJson((decoder as JsonDecoder).decodeJsonElement()) ?: throw IllegalArgumentException("Réponse inconnue")
    override fun serialize(encoder: Encoder, value: GivenAnswer) = (encoder as JsonEncoder).encodeJsonElement(value.json)
}
