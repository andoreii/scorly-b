import Foundation
import Observation
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureCourses
import ScorlyFeatureRound
import SwiftUI

/// Linear screen state machine; transitions are horizontal slides.
/// `play`/`confirm` carry `RoundPlayState` so navigation and round
/// state update atomically.
@MainActor
@Observable
final class AppFlow {
    enum Screen: Equatable {
        case home, setup, history, stats, settings, courses
        case play(RoundPlayState)
        case confirm(RoundPlayState)
        case courseEditor(CourseDraft?)
        /// `season` powers the SG card's vs-season comparison and is
        /// excluded from screen-identity equality below.
        case roundDetail(CompletedRound, season: [CompletedRound])

        /// Compares only case identity, ignoring associated state, so
        /// two `.play` entries count as "the same screen" for deduping.
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

    /// Visited screens; last is visible. Lets transition direction be
    /// inferred (push = forward slide, pop = back slide).
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

    /// Hard reset, e.g. landing on History after a round files without
    /// revealing the intermediate stack.
    func resetTo(_ screen: Screen) {
        guard current != screen else { return }
        Haptics.rigid()
        stack = [screen]
    }
}
