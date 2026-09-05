import Foundation

/// Portable, constrained preview action.
///
/// App Preview never executes arbitrary source closures. Providers lower a
/// supported subset of button mutations into these actions, and the signed
/// runtime applies them to `PreviewStateStore`.
enum PreviewAction: Equatable, Sendable {
    case set(
        stateName: String,
        value: PreviewStateValue
    )
    case add(
        stateName: String,
        amount: Double
    )
    case toggle(
        stateName: String
    )

    var stateName: String {
        switch self {
        case .set(let stateName, _),
             .add(let stateName, _),
             .toggle(let stateName):
            return stateName
        }
    }
}

/// A button can contain more than one safe state mutation while remaining
/// completely independent from an executable Swift closure.
struct PreviewActionProgram: Equatable, Sendable {
    let actions: [PreviewAction]

    init(actions: [PreviewAction]) {
        self.actions = actions
    }

    static let empty = PreviewActionProgram(
        actions: []
    )
}

enum PreviewActionValidationError: Error, Equatable, Sendable {
    case unknownState(String)
    case incompatibleAction(
        stateName: String,
        actionDescription: String
    )
}

extension PreviewActionValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownState(let stateName):
            return
                "Preview action references unknown @State '\(stateName)'."

        case .incompatibleAction(
            let stateName,
            let actionDescription
        ):
            return
                "Preview action '\(actionDescription)' is incompatible with @State '\(stateName)'."
        }
    }
}

enum PreviewActionValidator {
    static func validate(
        _ program: PreviewActionProgram,
        definitions: [PreviewStateDefinition]
    ) throws {
        let states = Dictionary(
            uniqueKeysWithValues:
                definitions.map {
                    ($0.name, $0.initialValue)
                }
        )

        for action in program.actions {
            guard let current =
                states[action.stateName] else {
                throw PreviewActionValidationError
                    .unknownState(action.stateName)
            }

            switch action {
            case .set(_, let value):
                guard sameValueKind(
                    current,
                    value
                ) else {
                    throw PreviewActionValidationError
                        .incompatibleAction(
                            stateName:
                                action.stateName,
                            actionDescription:
                                "set"
                        )
                }

            case .add:
                guard case .number = current else {
                    throw PreviewActionValidationError
                        .incompatibleAction(
                            stateName:
                                action.stateName,
                            actionDescription:
                                "add"
                        )
                }

            case .toggle:
                guard case .bool = current else {
                    throw PreviewActionValidationError
                        .incompatibleAction(
                            stateName:
                                action.stateName,
                            actionDescription:
                                "toggle"
                        )
                }
            }
        }
    }

    private static func sameValueKind(
        _ lhs: PreviewStateValue,
        _ rhs: PreviewStateValue
    ) -> Bool {
        switch (lhs, rhs) {
        case (.string, .string),
             (.bool, .bool),
             (.number, .number):
            return true

        default:
            return false
        }
    }
}

extension PreviewStateStore {
    /// Applies a validated action program to preview state.
    ///
    /// The operation performs a full compatibility preflight first, so an
    /// invalid program does not partially mutate state.
    @discardableResult
    func perform(
        _ program: PreviewActionProgram
    ) -> Bool {
        guard canPerform(program) else {
            return false
        }

        for action in program.actions {
            switch action {
            case .set(
                let stateName,
                let value
            ):
                setValue(
                    value,
                    for: stateName
                )

            case .add(
                let stateName,
                let amount
            ):
                guard case .number(let value) =
                    self.value(for: stateName) else {
                    return false
                }

                setValue(
                    .number(value + amount),
                    for: stateName
                )

            case .toggle(let stateName):
                guard case .bool(let value) =
                    self.value(for: stateName) else {
                    return false
                }

                setValue(
                    .bool(!value),
                    for: stateName
                )
            }
        }

        return true
    }

    private func canPerform(
        _ program: PreviewActionProgram
    ) -> Bool {
        for action in program.actions {
            guard let current =
                value(for: action.stateName) else {
                return false
            }

            switch action {
            case .set(_, let newValue):
                guard Self.samePreviewValueKind(
                    current,
                    newValue
                ) else {
                    return false
                }

            case .add:
                guard case .number = current else {
                    return false
                }

            case .toggle:
                guard case .bool = current else {
                    return false
                }
            }
        }

        return true
    }

    private static func samePreviewValueKind(
        _ lhs: PreviewStateValue,
        _ rhs: PreviewStateValue
    ) -> Bool {
        switch (lhs, rhs) {
        case (.string, .string),
             (.bool, .bool),
             (.number, .number):
            return true

        default:
            return false
        }
    }
}
