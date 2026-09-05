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
}
