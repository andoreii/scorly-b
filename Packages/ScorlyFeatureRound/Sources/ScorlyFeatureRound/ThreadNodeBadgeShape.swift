import ScorlyDesignSystem

enum ThreadNodeBadgeShape: Equatable {
    case circle
    case rectangle

    init(mode: TargetField.Mode) {
        self = mode == .putt ? .circle : .rectangle
    }
}
