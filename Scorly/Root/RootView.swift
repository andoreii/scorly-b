import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
import ScorlyFeatureHistory
import ScorlyFeatureRound
import Supabase
import SwiftData
import SwiftUI

/// Root scene. Auth gate, then a flow-driven switch between brutalist
/// screens with horizontal slide transitions.
///
/// Repositories are created (or recreated) whenever the authenticated
/// userId changes — this ensures the SwiftData predicates always filter
/// by the current user's UUID and the SyncEngine is scoped correctly.
struct RootView: View {
    let authService: AuthService
    let supabase: SupabaseClient
    let modelContainer: ModelContainer

    @State private var flow = AppFlow()
    @State private var setupForm = RoundSetupForm()
    @State private var courses: [Course] = []
    @State private var devBypassAuth = false
    @State private var coursesRepository: any CoursesRepository = InMemoryCoursesRepository()
    @State private var roundsRepository: any RoundsRepository = InMemoryRoundsRepository()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AuthGateView(
            authService: authService,
            forceAuthenticated: devBypassAuth,
            onDevBypass: devBypassClosure
        ) {
            content
                .task(id: authService.userId) {
                    await buildReposAndLoadCourses()
                }
        }
    }

    // Build live repos scoped to the current userId, then fetch courses.
    // Called whenever userId changes (sign-in, sign-out, account switch).
    private func buildReposAndLoadCourses() async {
        guard let userId = authService.userId else {
            courses = []
            coursesRepository = InMemoryCoursesRepository()
            roundsRepository = InMemoryRoundsRepository()
            return
        }
        let syncEngine = SyncEngine.make(
            modelContainer: modelContainer,
            remote: LiveSupabaseRemoteSyncAPI(supabase: supabase),
            network: LiveNetworkMonitor()
        )
        coursesRepository = CoursesRepositoryLive.make(
            modelContainer: modelContainer,
            userId: userId,
            syncEngine: syncEngine
        )
        roundsRepository = RoundsRepositoryLive.make(
            modelContainer: modelContainer,
            userId: userId,
            syncEngine: syncEngine,
            supabase: supabase
        )
        if let fetched = try? await coursesRepository.fetchAll() {
            courses = fetched
            seedDefaultCourseSelection()
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
                    onSignOut: signOut,
                    onSyncCourses: refreshCourses
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
            case let .play(state):
                PlayView(
                    state: state,
                    onBack: { flow.back() },
                    onFinish: { flow.go(.confirm(state)) }
                )
                .transition(transition)
            case let .confirm(state):
                ConfirmView(
                    state: state,
                    setupForm: setupForm,
                    authService: authService,
                    roundsRepository: roundsRepository,
                    onBack: { flow.back() },
                    onFinish: { flow.resetTo(.history) }
                )
                .transition(transition)
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
        let state = RoundPlayState(
            course: course,
            teeId: setupForm.teeId,
            holesPlayed: setupForm.holesPlayed
        )
        flow.go(.play(state))
    }

    private func refreshCourses() async {
        if let fetched = try? await coursesRepository.fetchAll() {
            courses = fetched
            seedDefaultCourseSelection()
        }
    }

    private func signOut() {
        Task { @MainActor in
            try? await authService.signOut()
            #if DEBUG
            devBypassAuth = false
            #endif
            flow.resetTo(.home)
        }
    }
}
