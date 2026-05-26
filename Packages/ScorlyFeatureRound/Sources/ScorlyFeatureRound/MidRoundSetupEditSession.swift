/// Transactional setup editing for an active round.
///
/// The play flow keeps its filing metadata unchanged until the user taps
/// save, so dismissing the editor cannot partially alter a completed round.
public struct MidRoundSetupEditSession: Sendable, Equatable {
    private let original: RoundSetupForm
    public var form: RoundSetupForm

    public init(editing form: RoundSetupForm) {
        original = form
        self.form = form
    }

    public mutating func commit() -> RoundSetupForm {
        form
    }

    public func cancel() -> RoundSetupForm {
        original
    }
}
