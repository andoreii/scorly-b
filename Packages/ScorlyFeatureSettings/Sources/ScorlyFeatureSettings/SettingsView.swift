import ScorlyDesignSystem
import SwiftUI

/// Brutalist settings page. One section today: course-archive
/// maintenance. The settings page acts as the home for anything that
/// isn't routine play — sync, identity, diagnostics. Each row gets a
/// section header and a single full-width action.
public struct SettingsView: View {
    let onBack: () -> Void
    let onSyncCourses: (() async -> Void)?
    let onSignOut: (() -> Void)?

    @State private var isSyncing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        onBack: @escaping () -> Void,
        onSyncCourses: (() async -> Void)? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onSyncCourses = onSyncCourses
        self.onSignOut = onSignOut
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "PREFERENCES", right: "SCORLY/B  ®")
            HairlineProgress(isLoading: isSyncing)
                .padding(.top, BrutalistSpacing.s)
            backRow
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            tagline

            dataSection
                .padding(.top, BrutalistSpacing.xl)

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
        Text("Tune\nthe rig.")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .lineSpacing(-4)
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
