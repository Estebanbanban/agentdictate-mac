import XCTest
@testable import AgentDictate

final class ReplacementsEngineTests: XCTestCase {

    func testPlainCaseInsensitive() {
        let rule = ReplacementRule(pattern: "claude", replacement: "Cortana")
        XCTAssertEqual(
            ReplacementsEngine.apply("Ask Claude please", rules: [rule]),
            "Ask Cortana please"
        )
    }

    func testPlainCaseSensitiveLeavesMismatchedCase() {
        let rule = ReplacementRule(pattern: "Claude", replacement: "Cortana", caseSensitive: true)
        XCTAssertEqual(
            ReplacementsEngine.apply("ask claude please", rules: [rule]),
            "ask claude please"
        )
    }

    func testRulesAreOrdered() {
        let r1 = ReplacementRule(pattern: "TODO", replacement: "DONE")
        let r2 = ReplacementRule(pattern: "DONE", replacement: "SHIPPED")
        XCTAssertEqual(
            ReplacementsEngine.apply("TODO list", rules: [r1, r2]),
            "SHIPPED list"
        )
    }

    func testDisabledRuleSkipped() {
        let rule = ReplacementRule(pattern: "x", replacement: "y", enabled: false)
        XCTAssertEqual(ReplacementsEngine.apply("xxx", rules: [rule]), "xxx")
    }

    func testRegexCapturesAndTemplate() {
        let rule = ReplacementRule(
            pattern: #"(\d+)\s*dollars"#,
            replacement: #"\$$1"#,
            mode: .regex
        )
        XCTAssertEqual(
            ReplacementsEngine.apply("It costs 50 dollars and 20 dollars", rules: [rule]),
            "It costs $50 and $20"
        )
    }

    func testInvalidRegexLeavesInputUntouched() {
        let rule = ReplacementRule(pattern: "(unterminated", replacement: "x", mode: .regex)
        XCTAssertEqual(ReplacementsEngine.apply("hello", rules: [rule]), "hello")
    }

    func testEmptyPatternIsNoop() {
        let rule = ReplacementRule(pattern: "", replacement: "x")
        XCTAssertEqual(ReplacementsEngine.apply("hello", rules: [rule]), "hello")
    }
}
