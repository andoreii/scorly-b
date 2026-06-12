import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Home for non-routine actions: sync, identity, diagnostics.
public struct SettingsView: View {
    let onBack: () -> Void
    let onSyncCourses: (() async -> Void)?
    let onFetchRounds: (() async throws -> Int)?
    let onSignOut: (() -> Void)?
    @Binding private var sgComparisonReference: SGComparisonReference
    /// Re-pushes every local round's hole detail to Supabase; nil hides the row.
    let onBackfillStats: (() async throws -> Int)?

    @State private var isSyncing = false
    @State private var isFetchingRounds = false
    @State private var fetchRoundsStatus: String?
    @State private var isBackfilling = false
    @State private var backfillStatus: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        onBack: @escaping () -> Void,
        onSyncCourses: (() async -> Void)? = nil,
        onFetchRounds: (() async throws -> Int)? = nil,
        onSignOut: (() -> Void)? = nil,
        onBackfillStats: (() async throws -> Int)? = nil,
        sgComparisonReference: Binding<SGComparisonReference> = .constant(.scratch)
    ) {
        self.onBack = onBack
        self.onSyncCourses = onSyncCourses
        self.onFetchRounds = onFetchRounds
        self.onSignOut = onSignOut
        self.onBackfillStats = onBackfillStats
        _sgComparisonReference = sgComparisonReference
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "PREFERENCES", right: "SCORLY/B  ®")
            HairlineProgress(isLoading: isSyncing || isFetchingRounds || isBackfilling)
                .padding(.top, BrutalistSpacing.s)
            backRow
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            tagline

            SGComparisonReferenceSection(reference: $sgComparisonReference)
                .padding(.top, BrutalistSpacing.xl)

            dataSection
                .padding(.top, BrutalistSpacing.xl)

            if onFetchRounds != nil {
                roundArchiveSection
                    .padding(.top, BrutalistSpacing.xl)
            }

            if onBackfillStats != nil {
                backfillSection
                    .padding(.top, BrutalistSpacing.xl)
            }

            identitySection
                .padding(.top, BrutalistSpacing.xl)

            footerLine
                .padding(.top, BrutalistSpacing.xxl)
                .padding(.bottom, BrutalistSpacing.xl)
        }
    }

    // MARK: - Sub-views

    private var backRow: some View {
        HStack {
            Text("← HOME")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap(action: onBack)
            Spacer()
            Text("MODEL /B")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var hero: some View {
        Text("Settings")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .foregroundStyle(BrutalistColor.fg)
            .padding(.bottom, BrutalistSpacing.xs)
    }

    private var tagline: some View {
        Text("MAINTENANCE · IDENTITY · DIAGNOSTICS")
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
    }

    @ViewBuilder
    private var dataSection: some View {
        sectionHeader(
            label: "Course Archive",
            sub: "PULL CANONICAL DATA FROM REMOTE"
        )
        if let onSyncCourses {
            BrutalistButton(
                kind: .ghost,
                action: {
                    guard !isSyncing else { return }
                    Task {
                        isSyncing = true
                        await onSyncCourses()
                        isSyncing = false
                    }
                },
                isDisabled: isSyncing,
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text(isSyncing ? "↓  SYNCING…" : "↓  SYNC COURSES")
                    .font(BrutalistType.sans(.bold, size: 16))
                    .kerning(-0.2)
            } caption: {
                Text(isSyncing ? "WAIT" : "FROM REMOTE")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.s)
            Text("Refreshes the local copy of every course, tee, and hole. Round records stay untouched.")
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.muted)
                .padding(.top, BrutalistSpacing.s)
        } else {
            disabledRow(
                title: "↓  SYNC COURSES",
                caption: "OFFLINE"
            )
            .padding(.top, BrutalistSpacing.s)
        }
    }

    @ViewBuilder
    private var roundArchiveSection: some View {
        sectionHeader(
            label: "Round Archive",
            sub: "PULL COMPLETED CARDS FROM REMOTE"
        )
        if let onFetchRounds {
            BrutalistButton(
                kind: .ghost,
                action: {
                    guard !isFetchingRounds else { return }
                    Task {
                        isFetchingRounds = true
                        defer { isFetchingRounds = false }
                        do {
                            let count = try await onFetchRounds()
                            fetchRoundsStatus = count == 0
                                ? "NO ROUNDS FOR SIGNED-IN USER"
                                : "\(count) ROUNDS FETCHED"
                        } catch {
                            fetchRoundsStatus = "FAILED: \(error.localizedDescription.uppercased())"
                        }
                    }
                },
                isDisabled: isFetchingRounds,
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text(isFetchingRounds ? "↓  FETCHING…" : "↓  FETCH ROUNDS")
                    .font(BrutalistType.sans(.bold, size: 16))
                    .kerning(-0.2)
            } caption: {
                Text(isFetchingRounds ? "WAIT" : "LATEST 20")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.s)
            Text("Imports the latest 20 completed rounds and hole stats for history and trends.")
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.muted)
                .padding(.top, BrutalistSpacing.s)
            if let fetchRoundsStatus {
                Text(fetchRoundsStatus)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                    .padding(.top, BrutalistSpacing.s)
            }
        }
    }

    @ViewBuilder
    private var backfillSection: some View {
        sectionHeader(
            label: "Round Detail",
            sub: "RE-PUSH FULL STATS TO REMOTE"
        )
        if let onBackfillStats {
            BrutalistButton(
                kind: .ghost,
                action: {
                    guard !isBackfilling else { return }
                    Task {
                        isBackfilling = true
                        defer { isBackfilling = false }
                        do {
                            let count = try await onBackfillStats()
                            backfillStatus = count == 0
                                ? "NO ROUNDS TO RE-PUSH"
                                : "\(count) HOLE STATS PUSHED"
                        } catch {
                            backfillStatus = "FAILED — \(error.localizedDescription.uppercased())"
                        }
                    }
                },
                isDisabled: isBackfilling,
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text(isBackfilling ? "↑  RE-PUSHING…" : "↑  RE-PUSH ROUND DETAIL")
                    .font(BrutalistType.sans(.bold, size: 16))
                    .kerning(-0.2)
            } caption: {
                Text(isBackfilling ? "WAIT" : "TO REMOTE")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.s)
            Text(
                "Upserts every saved round's hole stats (distances, clubs, pin, derived flags) into Supabase. " +
                    "Idempotent - safe to run multiple times."
            )
            .font(BrutalistType.inputBody)
            .foregroundStyle(BrutalistColor.muted)
            .padding(.top, BrutalistSpacing.s)
            if let backfillStatus {
                Text(backfillStatus)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                    .padding(.top, BrutalistSpacing.s)
            }
        }
    }

    @ViewBuilder
    private var identitySection: some View {
        sectionHeader(label: "Identity", sub: "ACCOUNT")
        if let onSignOut {
            BrutalistButton(
                kind: .ghost,
                action: {
                    Haptics.medium()
                    onSignOut()
                },
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text("↳  SIGN OUT")
                    .font(BrutalistType.sans(.bold, size: 16))
                    .kerning(-0.2)
            } caption: {
                Text("END SESSION")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.s)
        } else {
            disabledRow(title: "↳  SIGN OUT", caption: "UNAVAILABLE")
                .padding(.top, BrutalistSpacing.s)
        }
    }

    private func sectionHeader(label: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                Spacer()
                Text(sub.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
            }
            HBar(vMargin: 2)
        }
    }

    private func disabledRow(title: String, caption: String) -> some View {
        HStack {
            Text(title)
                .font(BrutalistType.sans(.bold, size: 16))
                .kerning(-0.2)
                .foregroundStyle(BrutalistColor.dim)
            Spacer()
            Text(caption)
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.dim)
        }
        .padding(18)
        .overlay(Rectangle().stroke(BrutalistColor.hair, lineWidth: 1))
    }

    private var footerLine: some View {
        HStack {
            Text("END OF SETTINGS")
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
}

private struct SGComparisonReferenceSection: View {
    @Binding var reference: SGComparisonReference

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("STROKES GAINED")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                Spacer()
                Text("COMPARISON REFERENCE")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
            }
            HBar(vMargin: 2)
            ChipGrid(
                options: SGComparisonReference.allCases.map(\.settingsLabel),
                selection: Binding(
                    get: { reference.settingsLabel },
                    set: { label in
                        guard let label,
                              let nextReference = SGComparisonReference.allCases.first(where: {
                                  $0.settingsLabel == label
                              })
                        else { return }
                        reference = nextReference
                    }
                ),
                columns: 2,
                allowsDeselect: false
            )
            Text(
                "Scratch uses the benchmark table. Personal avg compares against your latest 20 rounds with SG data."
            )
            .font(BrutalistType.inputBody)
            .foregroundStyle(BrutalistColor.muted)
        }
    }
}
