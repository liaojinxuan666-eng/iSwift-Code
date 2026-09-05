import Foundation
import Combine

/// Runtime storage for portable Preview IR state.
///
/// This is deliberately independent from SwiftUI's `@State`. Providers emit
/// portable state definitions, and the signed runtime owns the mutable values.
/// Future Binding/TextField/Toggle nodes can bind to this same store.
final class PreviewStateStore: ObservableObject {
    @Published private(set) var values: [String: PreviewStateValue]

    init(definitions: [PreviewStateDefinition]) {
        self.values = Dictionary(
            uniqueKeysWithValues: definitions.map {
                ($0.name, $0.initialValue)
            }
        )
    }

    func value(for name: String) -> PreviewStateValue? {
        values[name]
    }

    func setValue(
        _ value: PreviewStateValue,
        for name: String
    ) {
        guard values[name] != nil else {
            return
        }

        values[name] = value
    }

    func reload(
        definitions: [PreviewStateDefinition]
    ) {
        values = Dictionary(
            uniqueKeysWithValues: definitions.map {
                ($0.name, $0.initialValue)
            }
        )
    }

    func stringValue(for name: String) -> String {
        guard case .string(let value) = values[name] else {
            return ""
        }
        return value
    }

    func boolValue(for name: String) -> Bool {
        guard case .bool(let value) = values[name] else {
            return false
        }
        return value
    }

    func displayText(for name: String) -> String {
        values[name]?.displayText ?? ""
    }

    func resolveInterpolations(
        in template: String
    ) -> String {
        var result = template

        for (name, value) in values {
            result = result.replacingOccurrences(
                of: "\\(\(name))",
                with: value.displayText
            )
        }

        return result
    }
}
