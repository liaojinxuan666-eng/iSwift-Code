import XCTest
@testable import iSwiftCode

final class CompilerCoreTests: XCTestCase {
    private let compiler = SandboxSwiftCompiler()

    func testArithmeticAndVariables() {
        let result = compiler.run(source: """
        let base = 40
        var answer = base + 1
        answer = answer + 1
        print(answer)
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "42")
    }

    func testIfElse() {
        let result = compiler.run(source: """
        let ready = 6 * 7 == 42
        if ready {
            print("works")
        } else {
            print("failed")
        }
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "works")
    }

    func testLetCannotBeReassigned() {
        let result = compiler.run(source: """
        let value = 1
        value = 2
        """)

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.diagnostics.first?.message, "Cannot assign to value: 'value' is a 'let' constant.")
    }

    func testSyntaxErrorIncludesLocation() {
        let result = compiler.run(source: "let = 1")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.diagnostics.first?.location, SourceLocation(line: 1, column: 5))
    }

    func testCommentsAndStrings() {
        let result = compiler.run(source: """
        // This comment is ignored by the local compiler.
        print("iSwift " + "Code")
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "iSwift Code")
    }

    func testWhileLoop() {
        let result = compiler.run(source: """
        var index = 0
        var total = 0
        while index < 5 {
            index = index + 1
            total = total + index
        }
        print(total)
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "15")
    }

    func testBlockScopeSupportsShadowing() {
        let result = compiler.run(source: """
        let value = 1
        {
            let value = 2
            print(value)
        }
        print(value)
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "2\n1")
    }

    func testBlockLocalDoesNotEscape() {
        let result = compiler.run(source: """
        {
            let hidden = 7
        }
        print(hidden)
        """)

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.diagnostics.first?.message, "Cannot find 'hidden' in scope.")
    }

    func testBreakAndContinue() {
        let result = compiler.run(source: """
        var index = 0
        var total = 0
        while index < 5 {
            index = index + 1
            if index == 3 {
                continue
            }
            total = total + index
            if total > 7 {
                break
            }
        }
        print(total)
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "12")
    }

    func testNestedScopesAreUnwoundByBreak() {
        let result = compiler.run(source: """
        var index = 0
        while index < 3 {
            index = index + 1
            {
                let temporary = index
                if temporary == 2 {
                    break
                }
            }
        }
        print(index)
        """)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.output, "2")
    }

    func testBreakOutsideLoopIsRejected() {
        let result = compiler.run(source: "break")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.diagnostics.first?.message, "'break' is only allowed inside a loop.")
    }

    func testContinueOutsideLoopIsRejected() {
        let result = compiler.run(source: "continue")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.diagnostics.first?.message, "'continue' is only allowed inside a loop.")
    }
}
