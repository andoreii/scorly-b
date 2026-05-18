import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
import ScorlyFeatureHistory
import ScorlyFeatureRound
import SwiftUI

/// Root scene. Auth gate, then a flow-driven switch between brutalist
/// screens with horizontal slide transitions.
struct RootView: View {
    let authService: AuthService
    let roundsRepository: any RoundsRepository
    let coursesRepository: any CoursesRepository

    @State private var flow = AppFlow()
    @State private var setupForm = RoundSetupForm()
    @State private var courses: [Course] = []
    @State private var didLoadCourses = false
    @State private var devBypassAuth = false
    @State private var playState: RoundPlayState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AuthGateView(
            authService: authService,
            forceAuthenticated: devBypassAuth,
            onDevBypass: devBypassClosure
        ) {
            content
                .id(authService.userId ?? UUID())
                .task {
                    guard !didLoadCourses else { return }
                    didLoadCourses = true
                    if let fetched = try? await coursesRepository.fetchAll() {
                        courses = fetched
                        seedDefaultCourseSelection()
                    }
                }
        }
    }

    /// DEBUG-only escape hatch so we can walk through the brutalist
    /// screens before a signup flow exists. In RELEASE the closure is
    /// nil and the bypass button never renders.
    private var devBypassClosure: (() -> Void)? {
        #if DEBUG
        return { devBypassAuth = true }
        #else
        return nil
        #endif
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            BrutalistColor.bg.ignoresSafeArea()
            switch flow.current {
            case .home:
                HomeView(
                    flow: flow,
                    repository: roundsRepository,
                    onSignOut: signOut
                )
                .transition(transition)
            case .setup:
                SetupView(
                    form: $setupForm,
                    courses: courses,
                    onCancel: { flow.back() },
                    onTeeOff: startRound
                )
                .transition(transition)
            case .play:
                if let playState {
                    PlayView(
                        state: playState,
                        onBack: { flow.back() },
                        onFinish: { flow.go(.confirm) }
                    )
                    .transition(transition)
                } else {
                    FlowPlaceholder(title: "Round play", onBack: { flow.back() })
                        .transition(transition)
                }
            case .confirm:
                if let playState {
                    ConfirmView(
                        state: playState,
                        setupForm: setupForm,
                        authService: authService,
                        roundsRepository: roundsRepository,
                        onBack: { flow.back() },
                        onFinish: {
                            flow.go(.history)
                            self.playState = nil
                        }
                    )
                    .transition(transition)
                } else {
                    FlowPlaceholder(title: "Sign & file", onBack: { flow.back() })
                        .transition(transition)
                }
            case .history:
                HistoryView(
                    roundsRepository: roundsRepository,
                    onBack: { flow.resetTo(.home) }
                )
                .transition(transition)
            }
        }
        .animation(
            Motion.adaptive(Motion.easeOutQuart(0.32), reduceMotion: reduceMotion),
            value: flow.current
        )
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func seedDefaultCourseSelection() {
        guard setupForm.courseId == nil, let first = courses.first else { return }
        setupForm.courseId = first.id
        setupForm.teeId = first.tees.first?.id
    }

    private func startRound() {
        guard
            let courseId = setupForm.courseId,
            let course = courses.first(where: { $0.id == courseId })
        else { return }
        playState = RoundPlayState(
            course: course,
            teeId: setupForm.teeId,
            holesPlayed: setupForm.holesPlayed
        )
        flow.go(.play)
    }

    private func signOut() {
        Task { @MainActor in
            try? await authService.signOut()
            #if DEBUG
            devBypassAuth = false
            #endif
            playState = nil
            flow.resetTo(.home)
        }
    }
}
