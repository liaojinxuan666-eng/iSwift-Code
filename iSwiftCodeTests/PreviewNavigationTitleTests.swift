import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewNavigationTitleTests: XCTestCase {
    private func baselinePreview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath: "ContentView.swift"
                )
            )
    }

    private func navigationPreview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUINavigationPreviewProvider()
            .makePreview(
                PreviewRequest(
                    files: [
                        PreviewSourceFile(
                            path: "ContentView.swift",
                            contents: source
                        )
                    ],
                    entryFilePath: "ContentView.swift"
                )
            )
    }

    func testNavigationTitleLowersToPortableModifierIR() throws {
        let result = try baselinePreview(
            """
            VStack {
                Text("Home")
            }
            .navigationTitle("Home")
            """
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(
            result.document?.root,
            .modified(
                base: .vStack(
                    children: [.text("Home")]
                ),
                modifiers: [
                    .navigationTitle("Home")
                ]
            )
        )
    }

    func testNavigationTitleComposesWithExistingModifiers() throws {
        let result = try baselinePreview(
            """
            VStack {
                Text("Home")
            }
            .padding(20)
            .navigationTitle("Dashboard")
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .modified(
            _,
            let modifiers
        ) = result.document?.root else {
            return XCTFail("Expected modified root.")
        }

        let expected: [PreviewModifier] = [
            .padding(20),
            .navigationTitle("Dashboard")
        ]
        XCTAssertEqual(modifiers, expected)
    }

    func testNavigationDestinationKeepsItsOwnTitle() throws {
        let result = try navigationPreview(
            """
            NavigationStack {
                NavigationLink("Details") {
                    VStack {
                        Text("Destination")
                    }
                    .navigationTitle("Details")
                }
            }
            """
        )

        XCTAssertTrue(result.succeeded)

        guard case .navigationStack(let children) =
            result.document?.root,
            children.count == 1,
            case .navigationLink(_, let destination) = children[0],
            case .modified(_, let modifiers) = destination else {
            return XCTFail("Expected titled NavigationLink destination.")
        }

        XCTAssertTrue(
            modifiers.contains(
                .navigationTitle("Details")
            )
        )
    }

    func testMalformedNavigationTitleProducesDiagnostic() throws {
        let result = try baselinePreview(
            """
            VStack {
                Text("Home")
            }
            .navigationTitle(123)
            """
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.document)
        XCTAssertEqual(
            result.diagnostics.first?.severity,
            .error
        )
    }

    func testBuiltInTemplateIsARealMultiPagePreview() throws {
        let project = BuiltInProjectTemplates
            .swiftUIPreview
            .instantiate(
                projectIdentifier: "tests.navigation-demo",
                projectDisplayName: "Navigation Demo"
            )

        let entry = try XCTUnwrap(
            project.descriptor.entryFilePath
        )
        let data = try XCTUnwrap(
            project.initialFiles[entry]
        )
        let source = try XCTUnwrap(
            String(data: data, encoding: .utf8)
        )

        XCTAssertTrue(
            source.contains("NavigationLink(\"Open Details\")")
        )
        XCTAssertTrue(
            source.contains(".navigationTitle(\"Details\")")
        )
        XCTAssertTrue(
            source.contains(".navigationTitle(\"Navigation Demo\")")
        )

        let result = try navigationPreview(source)
        XCTAssertTrue(result.succeeded)
        XCTAssertNotNil(result.document)
    }
}
