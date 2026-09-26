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
}
