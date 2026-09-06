import Foundation
import XCTest
@testable import iSwiftCode

final class PreviewControlStyleTests:
    XCTestCase {
    private func preview(
        _ source: String
    ) throws -> PreviewProviderResult {
        try SwiftUIControlStylePreviewProvider()
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

    func testButtonStyleControlSizeAndTintLower() throws {
        let result = try preview(
            """
            Button("Build") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
            """
        )

        XCTAssertTrue(
            result.succeeded
        )

        let modifiers =
            try XCTUnwrap(
                rootModifiers(
                    result.document?.root
                )
            )

        XCTAssertTrue(
            modifiers.contains(
                .buttonStyle(
                    .borderedProminent
                )
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .controlSize(
                    .large
                )
            )
        )
        XCTAssertTrue(
            modifiers.contains(
                .tint(
                    .blue
                )
            )
        )
    }

    func testTextFieldRoundedBorderLowers() throws {
        let result = try preview(
            """
            @State private var name = ""

            TextField(
                "Name",
                text: $name
            )
            .textFieldStyle(.roundedBorder)
            """
        )

        XCTAssertTrue(
            result.succeeded
        )

        let modifiers =
            try XCTUnwrap(
                rootModifiers(
                    result.document?.root
                )
            )

        XCTAssertTrue(
            modifiers.contains(
                .textFieldStyle(
                    .roundedBorder
                )
            )
        )
    }

    func testPickerAndToggleStylesRewrite() throws {
        let source =
            """
            @State private var enabled = false

            VStack {
                Toggle(
                    "Enabled",
                    isOn: $enabled
                )
                .toggleStyle(.button)

                Text("Style carrier")
                    .pickerStyle(.segmented)
            }
            """

        let rewrite =
            try PreviewControlStyleSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertEqual(
            rewrite.markers.count,
            2
        )
        XCTAssertFalse(
            rewrite.source.contains(
                ".toggleStyle(.button)"
            )
        )
        XCTAssertFalse(
            rewrite.source.contains(
                ".pickerStyle(.segmented)"
            )
        )
    }

    func testStyleSyntaxInsideStringAndCommentIsIgnored() throws {
        let source =
            """
            Text(".buttonStyle(.bordered)")
            // .controlSize(.large)
            // .tint(.red)
            """

        let rewrite =
            try PreviewControlStyleSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertTrue(
            rewrite.markers.isEmpty
        )
        XCTAssertEqual(
            rewrite.source,
            source
        )
    }

    func testFirstWaveStyleSetRewrites() throws {
        let source =
            """
            Button("A") {}
                .buttonStyle(.plain)
                .textFieldStyle(.plain)
                .pickerStyle(.wheel)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
            """

        let rewrite =
            try PreviewControlStyleSourceRewriter(
                source: source
            ).rewrite()

        XCTAssertEqual(
            rewrite.markers.count,
            6
        )
    }

    private func rootModifiers(
        _ node: PreviewNode?
    ) -> [PreviewModifier]? {
        guard let node else {
            return nil
        }

        if case .modified(
            _,
            let modifiers
        ) = node {
            return modifiers
        }

        return nil
    }
}
