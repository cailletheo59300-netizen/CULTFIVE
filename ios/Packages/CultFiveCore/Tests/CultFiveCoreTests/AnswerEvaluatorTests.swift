import XCTest
@testable import CultFiveCore

final class AnswerEvaluatorTests: XCTestCase {
    func testMCQ() {
        let answer = CorrectAnswer(optionId: "b1")
        XCTAssertTrue(AnswerEvaluator.isCorrect(.option("b1"), type: .mcq, answer: answer))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.option("a1"), type: .mcq, answer: answer))
        XCTAssertFalse(AnswerEvaluator.isCorrect(nil, type: .mcq, answer: answer))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.bool(true), type: .mcq, answer: answer), "type incohérent ⇒ faux")
    }

    func testTrueFalse() {
        let answer = CorrectAnswer(value: .bool(false))
        XCTAssertTrue(AnswerEvaluator.isCorrect(.bool(false), type: .trueFalse, answer: answer))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.bool(true), type: .trueFalse, answer: answer))
    }

    func testNumericWithTolerance() {
        let marathon = CorrectAnswer(value: .number(42.195), tolerance: 0.001)
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(Decimal(string: "42.195")!), type: .numeric, answer: marathon))
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(Decimal(string: "42.196")!), type: .numeric, answer: marathon))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.number(42), type: .numeric, answer: marathon))
        let exact = CorrectAnswer(value: .number(102), tolerance: 0)
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(102), type: .numeric, answer: exact))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.number(Decimal(string: "102.1")!), type: .numeric, answer: exact))
    }

    func testOrderingAndPairs() {
        let order = CorrectAnswer(order: ["x", "y", "z"])
        XCTAssertTrue(AnswerEvaluator.isCorrect(.order(["x", "y", "z"]), type: .ordering, answer: order))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.order(["y", "x", "z"]), type: .ordering, answer: order))
        let pairs = CorrectAnswer(pairs: ["l1": "r1", "l2": "r2"])
        XCTAssertTrue(AnswerEvaluator.isCorrect(.pairs(["l2": "r2", "l1": "r1"]), type: .pairs, answer: pairs))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.pairs(["l1": "r2", "l2": "r1"]), type: .pairs, answer: pairs))
    }

    func testGivenAnswerEncodingMatchesServerFormat() throws {
        let data = try JSONEncoder().encode(GivenAnswer.option("abc"))
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"option_id":"abc"}"#)
        let roundTrip = try JSONDecoder().decode(GivenAnswer.self, from: JSONEncoder().encode(GivenAnswer.pairs(["a": "b"])))
        XCTAssertEqual(roundTrip, .pairs(["a": "b"]))
        let bool = try JSONDecoder().decode(GivenAnswer.self, from: Data(#"{"value":true}"#.utf8))
        XCTAssertEqual(bool, .bool(true))
    }
}

final class ShapeDecodingTests: XCTestCase {
    func testQuestionWithSilhouetteDecodes() throws {
        let json = #"{"id":"6f1a2b3c-0000-4000-8000-000000000001","type":"mcq","domain_id":"geography","subdomain_id":"geography.countries","prompt":"Quel pays a cette forme ?","payload":{"options":[{"id":"a","text":"Italie"},{"id":"b","text":"Grèce"}],"shape":{"paths":[[[0.1,0.2],[0.5,0.9],[0.8,0.3]]]}}}"#
        let question = try JSONDecoder().decode(Question.self, from: Data(json.utf8))
        XCTAssertEqual(question.payload.shape?.paths.first?.count, 3)
        XCTAssertEqual(question.payload.options?.count, 2)
    }

    // MARK: Nouveaux types (miroir de 99_answer_types.sql)

    func testMarginTypes() {
        let bones = CorrectAnswer(value: .number(206), tolerance: 10)
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(214), type: .counter, answer: bones))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.number(217), type: .counter, answer: bones))
        XCTAssertEqual(AnswerEvaluator.margin(.number(206), type: .counter, answer: bones), .exact)
        XCTAssertEqual(AnswerEvaluator.margin(.number(214), type: .counter, answer: bones), .within)
        XCTAssertEqual(AnswerEvaluator.margin(.number(230), type: .counter, answer: bones), .near)
        XCTAssertEqual(AnswerEvaluator.margin(.number(300), type: .counter, answer: bones), .missed)
        let rugby = CorrectAnswer(value: .number(15), tolerance: 0)
        XCTAssertFalse(AnswerEvaluator.isCorrect(.number(14), type: .counter, answer: rugby))
        XCTAssertEqual(AnswerEvaluator.margin(.number(14), type: .counter, answer: rugby), .near)
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(-60), type: .timeline, answer: CorrectAnswer(value: .number(-44), tolerance: 20)))
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(66), type: .gauge, answer: CorrectAnswer(value: .number(71), tolerance: 5)))
        XCTAssertNil(AnswerEvaluator.margin(.option("a"), type: .mcq, answer: CorrectAnswer(optionId: "a")))
    }

    func testProportion() {
        var giraffe = CorrectAnswer(value: .number(5.5))
        giraffe.relTolerance = 0.15
        XCTAssertTrue(AnswerEvaluator.isCorrect(.number(Decimal(string: "6.2")!), type: .proportion, answer: giraffe))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.number(Decimal(string: "6.4")!), type: .proportion, answer: giraffe))
        XCTAssertEqual(AnswerEvaluator.margin(.number(Decimal(string: "5.52")!), type: .proportion, answer: giraffe), .exact)
    }

    func testLettersAndWords() {
        var word = CorrectAnswer()
        word.word = "BAGUETTE"
        XCTAssertTrue(AnswerEvaluator.isCorrect(.text("baguette"), type: .letters, answer: word))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.text("BAGEUTTE"), type: .letters, answer: word))
        var motto = CorrectAnswer()
        motto.words = ["Tous", "pour", "un", "un", "pour", "tous"]
        XCTAssertTrue(AnswerEvaluator.isCorrect(.words(["Tous", "pour", "un", "un", "pour", "tous"]), type: .wordOrder, answer: motto))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.words(["un", "pour", "Tous", "un", "pour", "tous"]), type: .wordOrder, answer: motto))
        XCTAssertTrue(AnswerEvaluator.isCorrect(.option("be"), type: .imageChoice, answer: CorrectAnswer(optionId: "be")))
    }

    func testNewTypesDecode() throws {
        let json = """
        {"id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","type":"word_order","domain_id":"french","subdomain_id":"french.expressions",
         "prompt":"Remets ce proverbe dans l'ordre.","payload":{"tiles":[{"id":"t2","text":"nuit"},{"id":"t1","text":"La"}]},
         "answer":{"words":["La","nuit"],"sentence":"La nuit."},"explanation":"Mieux vaut dormir avant de décider."}
        """
        let question = try JSONDecoder().decode(Question.self, from: Data(json.utf8))
        XCTAssertEqual(question.type, .wordOrder)
        XCTAssertEqual(question.payload.tiles?.count, 2)
        XCTAssertEqual(question.reveal?.answer.words, ["La", "nuit"])
        let future = json.replacingOccurrences(of: "\"word_order\"", with: "\"hologram\"")
        XCTAssertEqual(try JSONDecoder().decode(Question.self, from: Data(future.utf8)).type, .unknown, "type futur : pas de plantage")
        let given = try JSONDecoder().decode(GivenAnswer.self, from: Data(#"{"words":["La","nuit"]}"#.utf8))
        XCTAssertEqual(given, .words(["La", "nuit"]))
        XCTAssertEqual(try JSONDecoder().decode(GivenAnswer.self, from: Data(#"{"text":"NUIT"}"#.utf8)), .text("NUIT"))
    }

    // MARK: Lot 2

    func testNumberTarget() {
        let steps = [TargetStep(a: 6, op: "+", b: 5), TargetStep(a: 11, op: "-", b: 2), TargetStep(a: 9, op: "*", b: 3)]
        XCTAssertTrue(AnswerEvaluator.reaches(27, from: [3, 6, 5, 2], with: steps))
        XCTAssertFalse(AnswerEvaluator.reaches(27, from: [3, 6, 5, 2], with: [TargetStep(a: 9, op: "*", b: 3)]), "9 pas disponible")
        XCTAssertFalse(AnswerEvaluator.reaches(36, from: [3, 6, 5, 2], with: [TargetStep(a: 6, op: "*", b: 6)]), "6 une seule fois")
        XCTAssertNil(TargetStep(a: 5, op: "/", b: 2).result)
        XCTAssertNil(TargetStep(a: 2, op: "-", b: 5).result)
        var answer = CorrectAnswer()
        answer.numbers = [3, 6, 5, 2]
        answer.target = 27
        XCTAssertTrue(AnswerEvaluator.isCorrect(.steps(steps), type: .numberTarget, answer: answer))
    }

    func testMapPinAndSort() throws {
        var strasbourg = CorrectAnswer()
        strasbourg.lat = 48.58
        strasbourg.lon = 7.75
        strasbourg.toleranceKm = 60
        let paris = try XCTUnwrap(AnswerEvaluator.distanceKm(lat: 48.86, lon: 2.35, answer: strasbourg))
        XCTAssertEqual(paris, 397, accuracy: 10)
        XCTAssertTrue(AnswerEvaluator.isCorrect(.pin(lat: 48.9, lon: 7.6), type: .mapPin, answer: strasbourg))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.pin(lat: 47.7, lon: 7.3), type: .mapPin, answer: strasbourg))
        XCTAssertEqual(AnswerEvaluator.margin(.pin(lat: 48.6, lon: 7.76), type: .mapPin, answer: strasbourg), .exact)
        var sorted = CorrectAnswer()
        sorted.groups = ["a": "x", "b": "y"]
        XCTAssertTrue(AnswerEvaluator.isCorrect(.groups(["b": "y", "a": "x"]), type: .sort, answer: sorted))
        XCTAssertFalse(AnswerEvaluator.isCorrect(.groups(["a": "y", "b": "y"]), type: .sort, answer: sorted))
        XCTAssertTrue(AnswerEvaluator.isCorrect(.riddle("o1", clues: 2), type: .riddle, answer: CorrectAnswer(optionId: "o1")))
        let given = try JSONDecoder().decode(GivenAnswer.self, from: Data(#"{"option_id":"o1","clues":1}"#.utf8))
        XCTAssertEqual(given, .riddle("o1", clues: 1))
        XCTAssertEqual(try JSONDecoder().decode(GivenAnswer.self, from: Data(#"{"lat":1.5,"lon":2}"#.utf8)), .pin(lat: 1.5, lon: 2))
    }
}
