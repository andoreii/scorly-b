import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyReviewKit
import SwiftUI

/// Round Detail screen, pushed from a History row tap.
public struct RoundDetailView: View {
    let round: CompletedRound
    let seasonRounds: [CompletedRound]
    let roundsRepository: any RoundsRepository
    let comparisonReference: SGComparisonReference
    let onBack: () -> Void
    let onDeleted: () -> Void

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    public init(
        round: CompletedRound,
        seasonRounds: [CompletedRound],
        roundsRepository: any RoundsRepository,
        comparisonReference: SGComparisonReference = .scratch,
        onBack: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.round = round
        self.seasonRounds = seasonRounds
        self.roundsRepository = roundsRepository
        self.comparisonReference = comparisonReference
        self.onBack = onBack
        self.onDeleted = onDeleted
    }

    public var body: some View {
        let metrics = RoundDetailMetrics(round: round)
        let sgProjection = SGReferenceProjection.project(
            reference: comparisonReference,
            totals: round.sgTotals,
            holes: round.sgHoles,
            baselineRounds: seasonRounds
        )
        ScreenShell {
            TopBar(left: "ROUND DETAIL", right: "SCORLY/B  ®")
            backRow
                .padding(.top, BrutalistSpacing.m)
            heroTitle
                .padding(.top, BrutalistSpacing.m)
            HBar(vMargin: BrutalistSpacing.m)
            RoundHeroStamp(
                dateLabel: "ROUND · \(dateString(round.datePlayed))",
                refLabel: "REF \(refString(round.id))",
                courseName: round.courseName ?? "—",
                caption: caption(for: round),
                score: round.totalScore,
                parLabel: parLabel(for: round)
            )
            RoundScorecardCard(groups: metrics.scorecardGroups)
                .padding(.top, BrutalistSpacing.l)
            StrokesGainedCard(
                meta: "ROUND \(refString(round.id)) · \(round.courseName?.uppercased() ?? "—")",
                total: sgProjection.totals.map(SGCardMapping.cardValues),
                holes: sgProjection.holes?.map(SGCardMapping.cardValues),
                seasonAverages: sgProjection.activeReference == .scratch
                    ? sgSeasonAverages(excluding: round.id, from: seasonRounds).map(SGCardMapping.cardValues)
                    : nil,
                referenceLabel: sgProjection.referenceLabel,
                summaryStyle: .categoryExtremes,
                breakdownDensity: .spacious
            )
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
            deleteSection
                .padding(.top, BrutalistSpacing.xl)
            footerLine
                .padding(.top, BrutalistSpacing.xl)
                .padding(.bottom, BrutalistSpacing.xl)
        }
        .confirmationDialog(
            "Delete this round?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete round", role: .destructive) {
                Task { await performDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will permanently remove the round, every hole's stats, "
                    + "and the record on Supabase. This cannot be undone."
            )
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            BrutalistButton(
                kind: .ghost,
                action: { showDeleteConfirm = true },
                isDisabled: isDeleting,
                title: {
                    Text(isDeleting ? "DELETING…" : "DELETE ROUND")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                },
                caption: {
                    Text("PERMANENT")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                }
            )
            if let deleteError {
                Text(deleteError.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.sgNeg)
            }
        }
    }

    @MainActor
    private func performDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await roundsRepository.delete(id: round.id)
            onDeleted()
        } catch {
            isDeleting = false
            deleteError = "Delete failed · \(error.localizedDescription)"
        }
    }

    // MARK: - Sub-views

    private var backRow: some View {
        HStack {
            Text("← ARCHIVE")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onBack)
            Spacer()
            Text("ID \(idTail(round.id))")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var heroTitle: some View {
        Text("Round\nin review.")
            .font(BrutalistType.sans(.bold, size: 36))
            .kerning(-1.4)
            .lineSpacing(-4)
            .foregroundStyle(BrutalistColor.fg)
    }

    private var footerLine: some View {
        HStack {
            Text("END OF RECORD")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
            Spacer()
            Text("SCORLY/B · 2026")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
        }
    }

    // MARK: - Formatters

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yy"
        return fmt.string(from: date).uppercased()
    }

    private func refString(_ id: UUID) -> String {
        "PRG-\(idTail(id))"
    }

    private func idTail(_ id: UUID) -> String {
        let raw = id.uuidString.replacingOccurrences(of: "-", with: "")
        return String(raw.suffix(4)).uppercased()
    }

    private func holesCount(_ round: CompletedRound) -> Int {
        switch round.holesPlayed {
        case .eighteen: return 18
        case .front9, .back9: return 9
        }
    }

    private func caption(for round: CompletedRound) -> String {
        var parts: [String] = []
        if let tee = round.teeName {
            parts.append("\(tee.uppercased()) TEES")
        }
        parts.append("\(holesCount(round)) HOLES")
        if let weather = weatherLabel(round.conditions) {
            parts.append(weather.uppercased())
        }
        return parts.joined(separator: " — ")
    }

    private func parLabel(for round: CompletedRound) -> String {
        let diff = round.scoreVsPar
        return "\(diff >= 0 ? "+\(diff)" : "\(diff)") · PAR \(round.par)"
    }

    private func weatherLabel(_ conditions: Conditions) -> String? {
        Conditions.labeledFlags
            .first { conditions.contains($0.flag) }?
            .label
    }
}
