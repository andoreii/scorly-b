import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Post-round summary, attestation + file. Derives all aggregate stats
/// from `RoundPlayState`, captures a signature, then persists the
/// completed round via `RoundsRepository.save`.
public struct ConfirmView: View {
    let state: RoundPlayState
    let authService: AuthService
    let roundsRepository: any RoundsRepository
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var notes = ""
    @State private var signatureStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var signed = false
    @State private var isFiling = false
    // Stable reference number for this scorecard session.
    @State private var ref = "PRG-\(Int.random(in: 1_000...9_999))"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: RoundPlayState,
        authService: AuthService,
        roundsRepository: any RoundsRepository,
        onBack: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.state = state
        self.authService = authService
        self.roundsRepository = roundsRepository
        self.onBack = onBack
        self.onFinish = onFinish
        _notes = State(initialValue: state.setupForm.notes)
    }

    // MARK: - Aggregate stats

    private var setupForm: RoundSetupForm {
        state.setupForm
    }

    private var n: Int {
        state.holes.count
    }

    private var totalPar: Int {
        state.holes.reduce(0) { $0 + $1.par }
    }

    private var diff: Int {
        state.totalStrokes - totalPar
    }

    private var allStats: [HoleStat?] {
        state.holes.indices.map { state.derivedStat(for: $0) }
    }

    private var totalPutts: Int {
        state.entries.reduce(0) { $0 + $1.putts }
    }

    private var par4or5Count: Int {
        state.holes.filter { $0.par > 3 }.count
    }

    private var firCount: Int {
        zip(state.holes, allStats).reduce(0) { acc, pair in
            let (hole, stat) = pair
            guard hole.par > 3, let s = stat else { return acc }
            return acc + (s.fairwayInRegulation ? 1 : 0)
        }
    }

    private var girCount: Int {
        allStats.reduce(0) { $0 + (($1?.greenInRegulation == true) ? 1 : 0) }
    }

    private var threePuttCount: Int {
        allStats.reduce(0) { $0 + (($1?.threePutt == true) ? 1 : 0) }
    }

    private var upDownCount: Int {
        allStats.reduce(0) { $0 + (($1?.upAndDown == true) ? 1 : 0) }
    }

    private var sandSaveCount: Int {
        allStats.reduce(0) { $0 + (($1?.sandSave == true) ? 1 : 0) }
    }

    private var penaltyTotal: Int {
        allStats.reduce(0) { $0 + ($1?.effectivePenaltyStrokes ?? 0) }
    }

    private var birdieCount: Int {
        zip(state.holes, state.entries).reduce(0) { acc, pair in
            let (hole, entry) = pair
            guard let s = entry.strokes else { return acc }
            return acc + (s < hole.par ? 1 : 0)
        }
    }

    private var bogeyPlusCount: Int {
        zip(state.holes, state.entries).reduce(0) { acc, pair in
            let (hole, entry) = pair
            guard let s = entry.strokes else { return acc }
            return acc + (s > hole.par ? 1 : 0)
        }
    }

    private var parCount: Int {
        n - birdieCount - bogeyPlusCount
    }

    // MARK: - Body

    public var body: some View {
        ScreenShell {
            TopBar(left: "SIGN & FILE", right: "SCORLY/B  ®")
            backRefRow
            stampPanel
                .padding(.top, BrutalistSpacing.m)
            courseTicket
                .padding(.top, BrutalistSpacing.s)
            statsRow1
                .padding(.top, BrutalistSpacing.s)
            statsRow2
            holeByHoleCard
                .padding(.top, BrutalistSpacing.s)
            notesField
                .padding(.top, BrutalistSpacing.s)
            signatureSection
                .padding(.top, BrutalistSpacing.s)
            HBar(vMargin: BrutalistSpacing.l)
            fileButton
                .padding(.bottom, BrutalistSpacing.xl)
        }
    }

    // MARK: - Sub-views

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

    private var stampPanel: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.invBg
            CornerMarks(inset: 6, color: BrutalistColor.invFg)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("FINAL SCORE")
                        .font(BrutalistType.monoMicro)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.invMuted)
                    Text("\(state.totalStrokes)")
                        .font(BrutalistType.sans(.bold, size: 96))
                        .kerning(-4.2)
                        .foregroundStyle(BrutalistColor.invFg)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(diff == 0 ? "E VS PAR \(totalPar)" : "\(diff > 0 ? "+" : "")\(diff) VS PAR \(totalPar)")
                        .font(BrutalistType.monoCaption)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.invFg)
                        .padding(.top, BrutalistSpacing.xs)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dateString)
                        .font(BrutalistType.monoMicro)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.invMuted)
                    Text("\(n) HOLES")
                        .font(BrutalistType.monoMicro)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.invMuted)
                }
            }
            .padding(22)
        }
    }

    private var courseTicket: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.course.name)
                    .font(BrutalistType.body)
                    .kerning(-0.2)
                Text(courseSubline)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
            }
            Spacer()
            if let player = setupForm.players.first {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(player.name)
                        .font(BrutalistType.body)
                        .kerning(-0.2)
                    Text("HCP \(handicapLabel(player.handicap))")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
        }
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var statsRow1: some View {
        HStack(spacing: 0) {
            BigStat(
                label: "Putts",
                value: "\(totalPutts)",
                sub: n > 0 ? "\(String(format: "%.1f", Double(totalPutts) / Double(n))) / HOLE" : nil
            )
            BigStat(
                label: "Fairways",
                value: par4or5Count > 0 ? "\(firCount)/\(par4or5Count)" : "—",
                sub: par4or5Count > 0 ? "\(Int(Double(firCount) / Double(par4or5Count) * 100))%" : nil,
                drawBorder: true
            )
            BigStat(
                label: "Greens",
                value: "\(girCount)/\(n)",
                sub: n > 0 ? "\(Int(Double(girCount) / Double(n) * 100))%" : nil,
                drawBorder: true
            )
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var statsRow2: some View {
        HStack(spacing: 0) {
            BigStat(label: "3-Putts", value: "\(threePuttCount)")
            BigStat(label: "Up & Down", value: "\(upDownCount)", drawBorder: true)
            BigStat(label: "Sand Save", value: "\(sandSaveCount)", drawBorder: true)
            BigStat(label: "Penalty", value: "\(penaltyTotal)", drawBorder: true)
        }
        .overlay(
            Rectangle().stroke(BrutalistColor.rule, lineWidth: 1)
                .padding(.top, -1)
        )
    }

    private var holeByHoleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HOLE BY HOLE")
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                if let player = setupForm.players.first {
                    if let hcp = player.handicap {
                        let net = state.totalStrokes - Int(truncating: hcp as NSDecimalNumber)
                        Text("NET \(net)")
                            .font(BrutalistType.monoMicro)
                            .kerning(1.0)
                            .foregroundStyle(BrutalistColor.muted)
                    } else {
                        Text("NET —")
                            .font(BrutalistType.monoMicro)
                            .kerning(1.0)
                            .foregroundStyle(BrutalistColor.muted)
                    }
                }
            }

            ForEach(scorecardRows.indices, id: \.self) { ri in
                let row = scorecardRows[ri]
                scoreRow(row: row, isFirst: ri == 0)
            }

            // Legend
            HStack(spacing: 14) {
                Legend(label: "\(birdieCount) BIRDIE+") {
                    Pip(strokes: 3, par: 4, size: 14, weight: 1)
                }
                Legend(label: "\(parCount) PAR") {
                    Pip(strokes: 4, par: 4, size: 14, weight: 1)
                }
                Legend(label: "\(bogeyPlusCount) BOGEY+") {
                    Pip(strokes: 5, par: 4, size: 14, weight: 1)
                }
            }
            .padding(.top, BrutalistSpacing.s)
        }
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func scoreRow(row: ScorecardRow, isFirst: Bool) -> some View {
        let sliceHoles = state.holes[row.from..<row.to]
        let sliceEntries = state.entries[row.from..<row.to]
        let scores = sliceHoles.indices.map { i in sliceEntries[i].strokes ?? sliceHoles[i].par }
        let pars = sliceHoles.map { $0.par }
        let loggedPar = zip(sliceHoles, sliceEntries).reduce(0) { acc, pair in
            pair.1.strokes != nil ? acc + pair.0.par : acc
        }
        let loggedTotal = sliceEntries.reduce(0) { $0 + ($1.strokes ?? 0) }
        let colCount = row.to - row.from

        return Group {
            HStack {
                Text(row.label)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                if loggedTotal > 0 {
                    let rowDiff = loggedTotal - loggedPar
                    Text("\(loggedTotal) · \(rowDiff >= 0 ? "+\(rowDiff)" : "\(rowDiff)")")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
            .padding(.top, isFirst ? BrutalistSpacing.s : BrutalistSpacing.m)
            .padding(.bottom, BrutalistSpacing.xs)

            ScoreBars(scores: scores, pars: pars)

            // Notation row
            HStack(spacing: 0) {
                ForEach(0..<colCount, id: \.self) { i in
                    let holeIdx = row.from + i
                    let hole = state.holes[holeIdx]
                    let entry = state.entries[holeIdx]
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", hole.number))
                            .font(BrutalistType.monoTick)
                            .foregroundStyle(BrutalistColor.dim)
                        Pip(strokes: entry.strokes, par: hole.par, size: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .overlay(alignment: .trailing) {
                        if i < colCount - 1 {
                            Rectangle().fill(BrutalistColor.hair).frame(width: 1)
                        }
                    }
                }
            }
            .overlay(Rectangle().stroke(BrutalistColor.hair, lineWidth: 1))
            .padding(.top, BrutalistSpacing.xs)
        }
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

    // MARK: - Helpers

    private func handicapLabel(_ handicap: Decimal?) -> String {
        guard let handicap else { return "—" }
        return String(format: "%.1f", Double(truncating: handicap as NSDecimalNumber))
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yy"
        return fmt.string(from: setupForm.datePlayed).uppercased()
    }

    private var courseSubline: String {
        var parts: [String] = []
        if let tee = state.tee {
            parts.append("\(tee.name.uppercased()) TEES")
        }
        parts.append("PAR \(totalPar)")
        if let slope = state.tee?.slopeRating {
            parts.append("SLP \(Int(truncating: slope as NSDecimalNumber))")
        }
        return parts.joined(separator: " — ")
    }

    private struct ScorecardRow {
        let label: String
        let from: Int
        let to: Int
    }

    private var scorecardRows: [ScorecardRow] {
        if n == 18 {
            return [
                ScorecardRow(label: "FRONT NINE", from: 0, to: 9),
                ScorecardRow(label: "BACK NINE", from: 9, to: 18),
            ]
        } else {
            let label = setupForm.holesPlayed == .back9 ? "BACK NINE" : "FRONT NINE"
            return [ScorecardRow(label: label, from: 0, to: n)]
        }
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
            startedAt: nil,
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
