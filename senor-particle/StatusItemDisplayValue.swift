/// What the status item shows: a vertical device label and one or two value rows.
nonisolated struct StatusItemDisplayValue: Equatable {
    let label: String
    let values: [String]
}
