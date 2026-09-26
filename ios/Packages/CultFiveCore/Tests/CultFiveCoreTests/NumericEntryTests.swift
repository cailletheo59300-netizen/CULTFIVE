import XCTest
@testable import CultFiveCore

final class NumericEntryTests: XCTestCase {
    func testDigitsAndGrouping() {
        var entry = NumericEntry()
        [3, 6, 0, 0].forEach { entry.append(digit: $0) }
        XCTAssertEqual(entry.value, 3600)
        XCTAssertEqual(entry.display(groupingSeparator: " "), "3 600")
    }

    func testNoLeadingZeros() {
        var entry = NumericEntry()
        entry.append(digit: 0)
        entry.append(digit: 0)
        entry.append(digit: 7)
        XCTAssertEqual(entry.display(), "7")
    }

    func testDecimalSeparator() {
        var entry = NumericEntry(maxDecimals: 3)
        entry.appendDecimalSeparator()
        XCTAssertEqual(entry.display(), "0,")
        [1, 2, 5, 9].forEach { entry.append(digit: $0) }
        XCTAssertEqual(entry.display(), "0,125", "3 décimales maximum")
        entry.appendDecimalSeparator()
        XCTAssertEqual(entry.value, Decimal(string: "0.125"))
    }

    func testBackspaceAndSign() {
        var entry = NumericEntry(allowNegative: true)
        entry.append(digit: 4)
        entry.toggleSign()
        XCTAssertEqual(entry.value, -4)
        XCTAssertEqual(entry.display(), "−4")
        entry.backspace()
        XCTAssertNil(entry.value)
        entry.backspace()
        XCTAssertFalse(entry.isNegative)
    }

    func testSignDisabledWhenNotAllowed() {
        var entry = NumericEntry(allowNegative: false)
        entry.append(digit: 1)
        entry.toggleSign()
        XCTAssertEqual(entry.value, 1)
    }

    func testMaxDigits() {
        var entry = NumericEntry(maxDigits: 3)
        [1, 2, 3, 4].forEach { entry.append(digit: $0) }
        XCTAssertEqual(entry.value, 123)
    }
}
