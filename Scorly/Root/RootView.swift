import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
import ScorlyFeatureCourses
import ScorlyFeatureHistory
import ScorlyFeatureRound
import ScorlyFeatureSettings
import ScorlyFeatureStats
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
    // Home's rounds + handicap live on the parent so they survive
    // every navigation. Without this, HomeView's local @State resets on
    // each remount and the "Last Round" stamp pops in mid-slide once
    // the async fetch resolves — instead of sliding in with the rest
    // of the screen.
    @State private var homeRounds: [CompletedRound] = []
    @State private var homeHandicap: Decimal?
    @State private var inProgressDraft: InProgressRoundDraft?
    @State private var inProgressSummary: InProgressSummary?
    @State private var showMidRoundSetup = false
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
                    await reloadHomeRounds()
                    await reloadInProgressDraft()
                }
                .task(id: flow.current) {
                    // Refetch when arriving on Home so the stamp
                    // reflects a freshly filed round (Confirm flow
                    // routes to History first, but the user often
                    // bounces back to Home).
                    if flow.current == .home {
                        await reloadHomeRounds()
                        await reloadInProgressDraft()
                    }
                }
        }
    }

    /// Build live repos scoped to the current userId, then fetch courses.
    /// Called whenever userId changes (sign-in, sign-out, account switch).
    private func buildReposAndLoadCourses() async {
        guard let userId = authService.userId else {
            courses = []
            coursesRepository = InMemoryCoursesRepository()
            roundsRepository = InMemoryRoundsRepository()
            return
        }
        let syncEngine = SyncEngine.make(
            modelContainer: modelContainer,
            remote: LiveSupabaseRemoteSyncAPI(
                supabase: supabase,
                modelContainer: modelContainer
            ),
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
        // Catch up the outbox on every userId-scoped rebuild (sign-in,
        // account switch, app launch). Then keep watching the network so
        // any future offline→online flip re-drains automatically.
        await syncEngine.startWatchingNetwork()
        Task { _ = await syncEngine.drain() }
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

    private var content: some View {
        ZStack {
            BrutalistColor.bg.ignoresSafeArea()
            switch flow.current {
            case .home:
                HomeView(
                    flow: flow,
                    rounds: homeRounds,
                    handicap: homeHandicap,
                    inProgress: inProgressSummary,
                    onResumeRound: resumeInProgressRound,
                    onDiscardDraft: discardInProgressDraft,
                    onStartNewRound: { flow.go(.setup) }
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
                    onGoHome: { exitToHome(from: state) },
                    onEditSetup: {
                        // Sync the form's holes-played to the round's
                        // current value so the picker reflects the
                        // active round (e.g. after a resume across app
                        // launches, where setupForm has reset).
                        setupForm.holesPlayed = state.holesPlayed
                        showMidRoundSetup = true
                    },
                    onFinish: { flow.go(.confirm(state)) },
                    onAutosave: { autosaveDraft(from: state) }
                )
                .transition(transition)
                .sheet(isPresented: $showMidRoundSetup) {
                    SetupView(
                        form: $setupForm,
                        courses: courses,
                        onCancel: { showMidRoundSetup = false },
                        onTeeOff: {
                            if setupForm.holesPlayed != state.holesPlayed {
                                state.changeHolesPlayed(to: setupForm.holesPlayed)
                                autosaveDraft(from: state)
                            }
                            showMidRoundSetup = false
                        },
                        editingActiveRound: true,
                        originalHolesPlayed: state.holesPlayed
                    )
                }
            case let .confirm(state):
                ConfirmView(
                    state: state,
                    setupForm: setupForm,
                    authService: authService,
                    roundsRepository: roundsRepository,
                    onBack: { flow.back() },
                    onFinish: {
                        Task {
                            try? await roundsRepository.deleteInProgressDraft()
                            await reloadInProgressDraft()
                            flow.resetTo(.history)
                        }
                    }
                )
                .transition(transition)
            case .history:
                HistoryView(
                    roundsRepository: roundsRepository,
                    onBack: { flow.resetTo(.home) }
                )
                .transition(transition)
            case .stats:
                TrendsView(
                    roundsRepository: roundsRepository,
                    onBack: { flow.resetTo(.home) }
                )
                .transition(transition)
            case .settings:
                SettingsView(
                    onBack: { flow.resetTo(.home) },
                    onSyncCourses: refreshCourses,
                    onSignOut: signOut
                )
                .transition(transition)
            case .courses:
                CoursesView(
                    coursesRepository: coursesRepository,
                    roundsRepository: roundsRepository,
                    onBack: { flow.resetTo(.home) },
                    onEdit: { draft in flow.go(.courseEditor(draft)) },
                    onNew: { flow.go(.courseEditor(nil)) }
                )
                .transition(transition)
            case let .courseEditor(draft):
                if let userId = authService.userId {
                    CourseEditorView(
                        coursesRepository: coursesRepository,
                        userId: userId,
                        initial: draft ?? CourseDraft.new(),
                        onCancel: { flow.back() },
                        onSaved: {
                            Task {
                                await refreshCourses()
                                flow.back()
                            }
                        }
                    )
                    .transition(transition)
                } else {
                    // Should never happen behind the auth gate. Drop
                    // the user back to courses if it does.
                    Color.clear.onAppear { flow.back() }
                }
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

    private func exitToHome(from state: RoundPlayState) {
        Task {
            await persistDraft(from: state)
            await reloadInProgressDraft()
            flow.resetTo(.home)
        }
    }

    private func autosaveDraft(from state: RoundPlayState) {
        Task { await persistDraft(from: state) }
    }

    @MainActor
    private func persistDraft(from state: RoundPlayState) async {
        guard let userId = authService.userId else { return }
        let payload = HoleEntriesCodec.encode(state.entries)
        let draftId = inProgressDraft?.id ?? UUID()
        let draft = InProgressRoundDraft(
            id: draftId,
            userId: userId,
            courseExternalId: state.course.externalId,
            teeExternalId: state.tee?.externalId,
            holesPlayed: state.holesPlayed,
            startedAt: state.startedAt,
            updatedAt: Date(),
            holeIdx: state.holeIdx,
            entriesPayload: payload
        )
        try? await roundsRepository.upsertInProgressDraft(draft)
        inProgressDraft = draft
    }

    private func resumeInProgressRound() {
        guard
            let draft = inProgressDraft,
            let course = courses.first(where: { $0.externalId == draft.courseExternalId })
        else { return }
        let entries = HoleEntriesCodec.decode(draft.entriesPayload) ?? []
        let teeId = draft.teeExternalId.flatMap { tid in
            course.tees.first(where: { $0.externalId == tid })?.id
        }
        let state = RoundPlayState(
            course: course,
            teeId: teeId,
            holesPlayed: draft.holesPlayed,
            entries: entries,
            holeIdx: draft.holeIdx,
            startedAt: draft.startedAt
        )
        flow.go(.play(state))
    }

    private func discardInProgressDraft() {
        Task {
            try? await roundsRepository.deleteInProgressDraft()
            inProgressDraft = nil
            inProgressSummary = nil
        }
    }

    private func refreshCourses() async {
        if let fetched = try? await coursesRepository.fetchAll() {
            courses = fetched
            seedDefaultCourseSelection()
        }
        // Syncing courses re-pulls rounds (via SyncEngine), so the
        // home-screen stats may be stale until we refetch them.
        await reloadHomeRounds()
    }

    @MainActor
    private func reloadHomeRounds() async {
        guard
            let fetched = try? await roundsRepository.fetchAllCompleted()
        else { return }
        let sorted = fetched.sorted { $0.datePlayed > $1.datePlayed }
        let differentials = fetched.compactMap(\.differential).prefix(20).map { $0 }
        homeRounds = sorted
        homeHandicap = WHSCalculator.handicapIndex(from: differentials)
        // Keep the "You" slot in setup in sync with the calculated index so
        // the read-only field in Round Setup always reflects the latest WHS
        // value rather than a stale captured one.
        if let first = setupForm.players.first {
            setupForm.players[0] = RoundSetupForm.Player(
                id: first.id,
                name: first.name,
                handicap: homeHandicap
            )
        }
    }

    @MainActor
    private func reloadInProgressDraft() async {
        let fetched = try? await roundsRepository.fetchInProgressDraft()
        inProgressDraft = fetched
        inProgressSummary = fetched.flatMap { buildSummary(from: $0) }
    }

    @MainActor
    private func buildSummary(from draft: InProgressRoundDraft) -> InProgressSummary? {
        guard
            let course = courses.first(where: { $0.externalId == draft.courseExternalId }),
            let entries = HoleEntriesCodec.decode(draft.entriesPayload)
        else { return nil }
        let sortedHoles = course.holes.sorted { $0.number < $1.number }
        let holes: [Hole]
        switch draft.holesPlayed {
        case .front9: holes = Array(sortedHoles.prefix(9))
        case .back9: holes = Array(sortedHoles.dropFirst(9).prefix(9))
        case .eighteen: holes = sortedHoles
        }
        guard !holes.isEmpty else { return nil }
        let totalStrokes = entries.reduce(0) { $0 + ($1.strokes ?? 0) }
        let totalPutts = entries.reduce(0) { $0 + $1.putts }
        let filledCount = entries.reduce(0) { $0 + ($1.strokes == nil ? 0 : 1) }
        let playedPar = zip(holes, entries).reduce(0) { acc, pair in
            pair.1.strokes != nil ? acc + pair.0.par : acc
        }
        let teeName = draft.teeExternalId
            .flatMap { tid in course.tees.first(where: { $0.externalId == tid })?.name }
        var subtitleParts: [String] = []
        if let teeName { subtitleParts.append("\(teeName.uppercased()) TEES") }
        subtitleParts.append("\(holes.count) HOLES")
        return InProgressSummary(
            courseName: course.name,
            subtitle: subtitleParts.joined(separator: " — "),
            startedAt: draft.startedAt,
            holeIdx: draft.holeIdx,
            totalHoles: holes.count,
            totalStrokes: totalStrokes,
            totalPutts: totalPutts,
            filledCount: filledCount,
            vsPar: totalStrokes - playedPar
        )
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
