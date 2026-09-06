import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewTextInputBehaviorTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUITextInputBehaviorPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path:
                                "ContentView.swift",
                            contents:
                                source
                        )
                    ],
                    entryFilePath:
                        "ContentView.swift"
                )
            )
    }

    func testSecureFieldUsesPortableStringBinding() throws {
        let result = try preview(
            """
            @State private var password = "secret"

            SecureField(
                "Password",
                text: $password
            )
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .secureField(
                prompt: "Password",
                text: PreviewBindingReference(
                    stateName: "password"
                )
            )
        )
    }

    func testTextInputModifiersLower() throws {
        let result = try preview(
            """
            @State private var email = ""

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            let base,
            let modifiers
        ) = result.document?.root else {
            return XCTFail(
                "Expected modified TextField"
            )
        }

        XCTAssertEqual(
            base,
            .textField(
                prompt: "Email",
                text: PreviewBindingReference(
                    stateName: "email"
                )
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .keyboardType(.emailAddress)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .textInputAutocapitalization(
                    .never
                )
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .autocorrectionDisabled(true)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .submitLabel(.done)
            )
        )
    }

    func testAutocorrectionFalseAndLabelsHiddenLower() throws {
        let result = try preview(
            """
            @State private var name = ""

            TextField("Name", text: $name)
                .autocorrectionDisabled(false)
                .labelsHidden()
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root else {
            return XCTFail(
                "Expected modified TextField"
            )
        }

        XCTAssertTrue(
            modifiers.contains(
                .autocorrectionDisabled(false)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .labelsHidden
            )
        )
    }

    func testURLKeyboardAndContinueSubmitLabelLower() throws {
        let result = try preview(
            """
            @State private var address = ""

            TextField("URL", text: $address)
                .keyboardType(.URL)
                .submitLabel(.continue)
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root else {
            return XCTFail(
                "Expected modified TextField"
            )
        }

        XCTAssertTrue(
            modifiers.contains(
                .keyboardType(.url)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .submitLabel(.continue)
            )
        )
    }

    func testInputModifiersInsideConditionalSurvive() throws {
        let result = try preview(
            """
            @State private var show = true
            @State private var email = ""

            VStack {
                if show {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .vStack(let children) =
                result.document?.root,
              case .conditional(
                _,
                let whenTrue,
                _
              ) = children.first,
              case .modified(
                _,
                let modifiers
              ) = whenTrue.first else {
            return XCTFail(
                "Expected conditional modified TextField"
            )
        }

        XCTAssertTrue(
            modifiers.contains(
                .keyboardType(.emailAddress)
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .submitLabel(.next)
            )
        )
    }

    func testInputSyntaxInsideStringsAndCommentsIsIgnored() throws {
        let source =
            """
            Text(".keyboardType(.emailAddress)")
            // .submitLabel(.done)
            /* SecureField("Fake", text: $fake) */
            """

        let rewrite =
            try PreviewTextInputSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertFalse(rewrite.hasChanges)
        XCTAssertEqual(
            rewrite.source,
            source
        )
    }
}
