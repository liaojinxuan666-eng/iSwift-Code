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

    /// Returns the wrapped value for optional primitive preview state.
    ///
    /// Non-optional state returns nil so presentation providers can distinguish
    /// an optional item binding from ordinary state.
    func optionalItemValue(
        for name: String
    ) -> PreviewStateValue? {
        switch values[name] {
        case .optionalString(let value):
            guard let value else {
                return nil
            }
            return .string(value)

        case .optionalBool(let value):
            guard let value else {
                return nil
            }
            return .bool(value)

        case .optionalNumber(let value):
            guard let value else {
                return nil
            }
            return .number(value)

        case .optionalIdentifiableItem(let state):
            guard let item = state.item else {
                return nil
            }
            return .identifiableItem(item)

        default:
            return nil
        }
    }

    func clearOptionalValue(
        for name: String
    ) {
        switch values[name] {
        case .optionalString:
            values[name] = .optionalString(nil)

        case .optionalBool:
            values[name] = .optionalBool(nil)

        case .optionalNumber:
            values[name] = .optionalNumber(nil)

        case .optionalIdentifiableItem(let state):
            values[name] = .optionalIdentifiableItem(
                state.clearing()
            )

        default:
            return
        }
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
