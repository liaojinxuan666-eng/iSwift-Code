import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewModifierTests: XCTestCase {
    private func preview(_ source: String) throws -> PreviewProviderResult {
        try SwiftUIPreviewProvider().makePreview(
            PreviewRequest(
                files: [PreviewSourceFile(path: "ContentView.swift", contents: source)],
                entryFilePath: "ContentView.swift"
            )
        )
    }

    func testPaddingFontAndForegroundStyleArePreservedInIR() throws {
        let result = try preview(
            """
            Text("Hello")
                .font(.title)
                .foregroundStyle(.red)
                .padding(16)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .text("Hello"),
                modifiers: [
                    .font(.title),
                    .foregroundStyle(.red),
                    .padding(16)
                ]
            )
        )
    }

    func testContainerModifiersApplyAfterChildren() throws {
        let result = try preview(
            """
            VStack {
                Text("A")
                Text("B")
            }
            .padding()
            .background(.blue)
            .cornerRadius(12)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .vStack(children: [.text("A"), .text("B")]),
                modifiers: [
                    .padding(nil),
                    .background(.blue),
                    .cornerRadius(12)
                ]
            )
        )
    }

    func testFrameSupportsFixedAndInfinityDimensions() throws {
        let fixed = try preview("Text(\"Fixed\").frame(width: 200, height: 80)")
        XCTAssertEqual(
            fixed.document?.root,
            .modified(
                base: .text("Fixed"),
                modifiers: [
                    .frame(PreviewFrame(width: 200, height: 80))
                ]
            )
        )

        let flexible = try preview("Text(\"Wide\").frame(maxWidth: .infinity, maxHeight: 300)")
        XCTAssertEqual(
            flexible.document?.root,
            .modified(
                base: .text("Wide"),
                modifiers: [
                    .frame(
                        PreviewFrame(
                            maxWidth: .infinity,
                            maxHeight: .points(300)
                        )
                    )
                ]
            )
        )
    }

    func testNestedNodesKeepIndependentModifiers() throws {
        let result = try preview(
            """
            HStack {
                Text("Left").foregroundStyle(.green)
                Spacer()
                Text("Right").font(.caption)
            }
            .padding(8)
            """
        )

        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .hStack(children: [
                    .modified(base: .text("Left"), modifiers: [.foregroundStyle(.green)]),
                    .spacer,
                    .modified(base: .text("Right"), modifiers: [.font(.caption)])
                ]),
                modifiers: [.padding(8)]
            )
        )
    }

    func testMalformedSupportedModifierProducesDiagnostic() throws {
        let result = try preview("Text(\"Hello\").cornerRadius()")

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertEqual(result.diagnostics.first?.severity, .error)
    }

    func testBuiltInTemplateUsesModifierIR() throws {
        let project = BuiltInProjectTemplates.swiftUIPreview.instantiate(
            projectIdentifier: "tests.modifier-template",
            projectDisplayName: "Styled Preview"
        )

        let entry = try XCTUnwrap(project.descriptor.entryFilePath)
        let data = try XCTUnwrap(project.initialFiles[entry])
        let source = try XCTUnwrap(String(data: data, encoding: .utf8))
        let result = try preview(source)

        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
