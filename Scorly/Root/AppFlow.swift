import Foundation
import Observation
import ScorlyDesignSystem
import SwiftUI

/// Linear screen state machine matching the brutalist design source.
/// Five primary screens; transitions are horizontal slides.
@MainActor
@Observable
final class AppFlow {
    enum Screen: Hashable {
        case home, setup, play, confirm, history
    }

    /// Stack of visited screens. Last is the visible screen. We keep a
    /// stack so transition direction can be inferred (going deeper =
    /// forward slide, popping = back slide).
    private(set) var stack: [Screen] = [.home]

    var current: Screen { stack.last ?? .home }

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
