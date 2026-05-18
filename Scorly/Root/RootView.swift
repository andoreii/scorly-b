import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AuthGateView(authService: authService) {
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
                    onTeeOff: { flow.go(.play) }
                )
                .transition(transition)
            case .play:
                FlowPlaceholder(title: "Round play", onBack: { flow.back() })
                    .transition(transition)
            case .confirm:
                FlowPlaceholder(title: "Sign & file", onBack: { flow.back() })
                    .transition(transition)
            case .history:
                FlowPlaceholder(title: "Round archive", onBack: { flow.back() })
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

    private func signOut() {
        Task { @MainActor in
            try? await authService.signOut()
            flow.resetTo(.home)
        }
    }
}
