import Foundation
import Observation
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureCourses
import ScorlyFeatureRound
import SwiftUI

/// Linear screen state machine matching the brutalist design source.
/// Five primary screens; transitions are horizontal slides.
///
/// `play` and `confirm` carry their `RoundPlayState` as an associated
/// value so navigation and round-state propagation are inherently
/// atomic — there's no possibility of rendering the .play branch
/// before the play state is observable.
@MainActor
@Observable
final class AppFlow {
    enum Screen: Equatable {
        case home, setup, history, stats, settings, courses
        case play(RoundPlayState)
        case confirm(RoundPlayState)
        case courseEditor(CourseDraft?)
        /// Round Detail. The season list is metadata passed through to
        /// the destination view (powers the SG card's vs-season
        /// comparison); it intentionally does not participate in screen
        /// identity for `flow.go` deduping.
        case roundDetail(CompletedRound, season: [CompletedRound])

        /// Equality compares only the case identity, not the associated
        /// state. Two `.play` entries are "the same screen" for the
        /// purposes of `flow.go` deduping.
        var caseTag: Int {
            switch self {
            case .home: 0
            case .setup: 1
            case .history: 2
            case .play: 3
            case .confirm: 4
            case .stats: 5
            case .settings: 6
            case .courses: 7
            case .courseEditor: 8
            case .roundDetail: 9
            }
        }

        static func == (lhs: Screen, rhs: Screen) -> Bool {
            lhs.caseTag == rhs.caseTag
        }
    }

    /// Stack of visited screens. Last is the visible screen. We keep a
    /// stack so transition direction can be inferred (going deeper =
    /// forward slide, popping = back slide).
    private(set) var stack: [Screen] = [.home]

    var current: Screen {
        stack.last ?? .home
    }

    /// Forward navigation. Pushes the screen.
    func go(_ screen: Screen) {
        guard screen != current else { return }
        Haptics.rigid()
        stack.append(screen)
    }

    /// Back navigation. Pops the last screen unless we're at home.
    func back() {
        guard stack.count > 1 else { return }
        Haptics.rigid()
        stack.removeLast()
    }

    /// Hard reset to home — used when a round files and we want to
    /// land on History without revealing the intermediate stack.
    func resetTo(_ screen: Screen) {
        guard current != screen else { return }
        Haptics.rigid()
        stack = [screen]
    }
}
