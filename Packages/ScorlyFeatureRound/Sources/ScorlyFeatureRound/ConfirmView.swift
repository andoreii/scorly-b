import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyReviewKit
import SwiftUI

/// Post-round summary, attestation + file. Mirrors `RoundDetailView`'s
/// layout so the player sees the same numbers later in History.
public struct ConfirmView: View {
    let state: RoundPlayState
    let authService: AuthService
    let roundsRepository: any RoundsRepository
    let comparisonReference: SGComparisonReference
    let baselineRounds: [CompletedRound]
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var notes = ""
    @State private var signatureStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var signed = false
    @State private var isFiling = false
    @State private var refineSheetOpen = false
    // Stable reference number for this scorecard session.
    @State private var ref = "PRG-\(Int.random(in: 1_000...9_999))"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: RoundPlayState,
        authService: AuthService,
        roundsRepository: any RoundsRepository,
        comparisonReference: SGComparisonReference = .scratch,
        baselineRounds: [CompletedRound] = [],
        onBack: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.state = state
        self.authService = authService
        self.roundsRepository = roundsRepository
        self.comparisonReference = comparisonReference
        self.baselineRounds = baselineRounds
        self.onBack = onBack
        self.onFinish = onFinish
        _notes = State(initialValue: state.setupForm.notes)
    }

    // MARK: - Data derivations

    private var setupForm: RoundSetupForm {
        state.setupForm
    }

    private var totalPar: Int {
        state.holes.reduce(0) { $0 + $1.par }
    }

    private var diff: Int {
        state.totalStrokes - totalPar
    }

    /// HoleStat snapshots for every hole (par-filled for unplayed),
    /// matching what `fileScorecard()` persists.
    private var derivedHoleStats: [HoleStat] {
        state.holes.indices.map { state.derivedStat(for: $0) }
    }

    private var derivedHolesPlayed: HolesPlayed {
        if state.holes.count == 18 { return .eighteen }
        if (state.holes.first?.number ?? 1) >= 10 { return .back9 }
        return .front9
    }

    // MARK: - Body

    public var body: some View {
        let stats = derivedHoleStats
        let metrics = RoundDetailMetrics(holeStats: stats, holesPlayed: derivedHolesPlayed)
        let sg = previewSG(stats: stats)

        ScreenShell {
            TopBar(left: "SIGN & FILE", right: "SCORLY/B  ®")
            backRefRow
            RoundHeroStamp(
                dateLabel: "ROUND · \(dateLabel)",
                refLabel: "REF \(ref)",
                courseName: state.course.name,
                caption: heroCaption,
                score: state.totalStrokes,
                parLabel: parLabel
            )
            .padding(.top, BrutalistSpacing.m)
            RoundScorecardCard(groups: metrics.scorecardGroups)
                .padding(.top, BrutalistSpacing.l)
            sgCardWithRefine(sg: sg)
                .padding(.top, BrutalistSpacing.l)
            AccuracyRoseCard(kind: .fairway, values: metrics.fairwayRose)
                .padding(.top, BrutalistSpacing.l)
            AccuracyRoseCard(kind: .green, values: metrics.greenRose)
                .padding(.top, BrutalistSpacing.l)
            PuttingSummaryCard(
                totalPutts: metrics.totalPutts,
                averagePuttsPerHole: metrics.averagePuttsPerHole,
                stats: metrics.puttMakeStats
            )
            .padding(.top, BrutalistSpacing.l)
            ScoringDistributionCard(
                counts: metrics.outcomes,
                total: metrics.playedHoleCount
            )
            .padding(.top, BrutalistSpacing.l)
            notesField
                .padding(.top, BrutalistSpacing.l)
            signatureSection
                .padding(.top, BrutalistSpacing.s)
            HBar(vMargin: BrutalistSpacing.l)
            fileButton
                .padding(.bottom, BrutalistSpacing.xl)
        }
        .sheet(isPresented: $refineSheetOpen) {
            SGRefinementSheet(state: state)
        }
    }

    // MARK: - Sub-views

    /// Shows a "tap to refine" caption above the SG card when any
    /// hole has an estimated chip phase.
    @ViewBuilder
    private func sgCardWithRefine(
        sg: (totals: SGTotals?, holes: [SGTotals]?)
    ) -> some View {
        let estimatedCount = estimatedHoleCount
        let projection = SGReferenceProjection.project(
            reference: comparisonReference,
            totals: sg.totals,
            holes: sg.holes,
            baselineRounds: baselineRounds
        )
        VStack(alignment: .leading, spacing: 6) {
            if estimatedCount > 0 {
                Text("TAP TO REFINE · \(estimatedCount) HOLES ESTIMATED")
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                    .brutalistTap {
                        Haptics.soft()
                        refineSheetOpen = true
                    }
            }
            StrokesGainedCard(
                meta: "ROUND \(ref) · \(state.course.name.uppercased())",
                total: projection.totals.map(SGCardMapping.cardValues),
                holes: projection.holes?.map(SGCardMapping.cardValues),
                seasonAverages: nil,
                referenceLabel: projection.referenceLabel,
                summaryStyle: .categoryExtremes,
                breakdownDensity: .spacious
            )
        }
    }

    /// Holes with an unrecorded chip phase; shown as "ESTIMATED" since
    /// the SG calculator falls back to lie-based defaults for them.
    private var estimatedHoleCount: Int {
        state.holes.indices.reduce(0) { acc, index in
            let inferred = state.inferredARGCount(at: index)
            guard inferred > 0 else { return acc }
            let recorded = state.recordedARGCount(at: index)
            return acc + (recorded >= inferred ? 0 : 1)
        }
    }

    private var backRefRow: some View {
        HStack {
            Text("← BACK")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onBack)
            Spacer()
            Text("SCORECARD · REF \(ref)")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
        .padding(.top, BrutalistSpacing.m)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.xs) {
            Text("NOTES — OPTIONAL")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            TextEditor(text: $notes)
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.fg)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 56)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Conditions, club picks, hot streaks…")
                            .font(BrutalistType.inputBody)
                            .foregroundStyle(BrutalistColor.dim)
                            .allowsHitTesting(false)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                }
                .padding(10)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.xs) {
            HStack {
                Text("ATTEST — SIGN HERE")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text("CLEAR")
                    .font(BrutalistType.monoLabel)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                    .brutalistTap {
                        Haptics.light()
                        signatureStrokes = []
                        currentStroke = []
                        signed = false
                    }
            }

            signatureCanvas
                .frame(height: 88)
                .background(BrutalistColor.panel)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))

            Text("BY SIGNING YOU ATTEST THE ABOVE IS A TRUE AND ACCURATE SCORECARD.")
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var signatureCanvas: some View {
        Canvas { ctx, _ in
            let style = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            for stroke in signatureStrokes {
                guard stroke.count >= 2 else { continue }
                var path = Path()
                path.move(to: stroke[0])
                for pt in stroke.dropFirst() {
                    path.addLine(to: pt)
                }
                ctx.stroke(path, with: .color(BrutalistColor.fg), style: style)
            }
            if currentStroke.count >= 2 {
                var path = Path()
                path.move(to: currentStroke[0])
                for pt in currentStroke.dropFirst() {
                    path.addLine(to: pt)
                }
                ctx.stroke(path, with: .color(BrutalistColor.fg), style: style)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !signed {
                        withAnimation(Motion.adaptive(Motion.easeOutQuart(0.28), reduceMotion: reduceMotion)) {
                            signed = true
                        }
                    }
                    currentStroke.append(value.location)
                }
                .onEnded { _ in
                    if !currentStroke.isEmpty {
                        signatureStrokes.append(currentStroke)
                        currentStroke = []
                    }
                }
        )
    }

    private var fileButton: some View {
        BrutalistButton(
            kind: .fg,
            action: { Task { await fileScorecard() } },
            isDisabled: !signed || isFiling,
            padding: EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
        ) {
            Text(isFiling ? "Filing…" : (signed ? "File scorecard" : "Sign to file"))
                .font(BrutalistType.body)
                .kerning(-0.2)
        } caption: {
            Text("→ POST")
                .font(BrutalistType.monoCaption)
                .kerning(1.2)
        }
    }

    // MARK: - Hero stamp formatters

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yy"
        return fmt.string(from: setupForm.datePlayed).uppercased()
    }

    private var heroCaption: String {
        var parts: [String] = []
        if let tee = state.tee {
            parts.append("\(tee.name.uppercased()) TEES")
        }
        parts.append("\(state.holes.count) HOLES")
        if let weather = weatherLabel(setupForm.conditions) {
            parts.append(weather.uppercased())
        }
        return parts.joined(separator: " — ")
    }

    private var parLabel: String {
        "\(diff >= 0 ? "+\(diff)" : "\(diff)") · PAR \(totalPar)"
    }

    private func weatherLabel(_ conditions: Conditions) -> String? {
        Conditions.labeledFlags
            .first { conditions.contains($0.flag) }?
            .label
    }

    // MARK: - SG preview

    private func previewSG(stats: [HoleStat]) -> (totals: SGTotals?, holes: [SGTotals]?) {
        SGPreview.compute(
            holes: state.holes,
            stats: stats,
            yardageByHoleNumber: teeYardageByHoleNumber
        )
    }

    private var teeYardageByHoleNumber: [Int: Int] {
        guard let tee = state.tee else { return [:] }
        return Dictionary(uniqueKeysWithValues: tee.teeHoles.map { ($0.holeNumber, $0.yardage) })
    }

    // MARK: - Save

    @MainActor
    private func fileScorecard() async {
        guard let userId = authService.userId else { return }
        isFiling = true
        let holeStats = state.holes.indices.compactMap { state.derivedStat(for: $0) }
        let players = setupForm.players.map { RoundPlayer(name: $0.name, handicap: $0.handicap) }
        // Derive holes_played from the slice actually played so the DB
        // row matches reality even if the form's value drifted between
        // setup and file (the live state.holes is the ground truth).
        let derivedHoles: HolesPlayed = {
            if state.holes.count == 18 { return .eighteen }
            if (state.holes.first?.number ?? 1) >= 10 { return .back9 }
            return .front9
        }()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: userId,
            courseId: state.course.externalId,
            teeId: state.tee?.externalId,
            datePlayed: setupForm.datePlayed,
            holesPlayed: derivedHoles,
            roundType: setupForm.roundType,
            roundFormat: setupForm.roundFormat,
            conditions: setupForm.conditions,
            temperature: setupForm.temperature,
            walkingVsRiding: setupForm.walkingVsRiding,
            startedAt: state.startedAt,
            finishedAt: Date(),
            mentalState: setupForm.mentalState,
            notes: notes.isEmpty ? nil : notes,
            totalScore: state.totalStrokes,
            whsDifferential: nil,
            createdAt: Date(),
            holeStats: holeStats,
            players: players
        )
        do {
            try await roundsRepository.save(draft)
        } catch {
            // Silently continue — SyncEngine will retry on next launch.
        }
        isFiling = false
        onFinish()
    }
}
