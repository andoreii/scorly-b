import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Course archive. List of the user's courses rendered as
/// hairline-bordered tickets (same family as History rows). Tap a row
/// to edit; the "+ NEW COURSE" CTA at the top of the list routes to
/// the editor with an empty draft.
public struct CoursesView: View {
    let coursesRepository: any CoursesRepository
    let roundsRepository: any RoundsRepository
    let onBack: () -> Void
    let onEdit: (CourseDraft) -> Void
    let onNew: () -> Void

    @State private var courses: [Course] = []
    @State private var eligibleBests: [UUID: Int] = [:]
    @State private var didLoad = false
    @State private var isRefreshing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        coursesRepository: any CoursesRepository,
        roundsRepository: any RoundsRepository,
        onBack: @escaping () -> Void,
        onEdit: @escaping (CourseDraft) -> Void,
        onNew: @escaping () -> Void
    ) {
        self.coursesRepository = coursesRepository
        self.roundsRepository = roundsRepository
        self.onBack = onBack
        self.onEdit = onEdit
        self.onNew = onNew
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "COURSE ARCHIVE", right: "SCORLY/B  ®")
            HairlineProgress(isLoading: isRefreshing)
                .padding(.top, BrutalistSpacing.s)
            backRow
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            tagline
            newCourseCta
                .padding(.top, BrutalistSpacing.l)
            courseList
                .padding(.top, BrutalistSpacing.m)
            footerLine
                .padding(.top, BrutalistSpacing.xl)
                .padding(.bottom, BrutalistSpacing.xl)
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await reload()
        }
        .refreshable { await reload() }
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
            Text("\(courses.count) COURSES")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var hero: some View {
        Text("Every\nlayout.")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .lineSpacing(-4)
            .foregroundStyle(BrutalistColor.fg)
            .padding(.bottom, BrutalistSpacing.xs)
    }

    private var tagline: some View {
        Text("ADD · EDIT · DELETE")
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
    }

    private var newCourseCta: some View {
        BrutalistButton(
            kind: .fg,
            action: {
                Haptics.rigid()
                onNew()
            },
            padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        ) {
            Text("+ Add course")
                .font(BrutalistType.sans(.bold, size: 17))
                .kerning(-0.3)
        } caption: {
            Text("→ NEW")
                .font(BrutalistType.monoCaption)
                .kerning(1.2)
        }
    }

    @ViewBuilder
    private var courseList: some View {
        if courses.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(courses) { course in
                    courseCard(course)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            Text("NO COURSES YET")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Text("Add your first course above — or sync from remote in Settings.")
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func courseCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(headerLine(course))
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text("REF \(referenceCode(course))")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            HBar(vMargin: 10)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(BrutalistType.sans(.bold, size: 18))
                        .kerning(-0.4)
                        .lineLimit(2)
                    Text(subline(course))
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(course.roundsPlayed)")
                        .font(BrutalistType.sans(.bold, size: 32))
                        .kerning(-1.0)
                        .monospacedDigit()
                    Text("ROUNDS")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
            HBar(vMargin: 10)
            HStack(spacing: 4) {
                MiniStat(label: "Tees", value: "\(course.tees.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                MiniStat(label: "Holes", value: "\(course.holes.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                MiniStat(label: "Best", value: bestScore(course))
                    .frame(maxWidth: .infinity, alignment: .leading)
                MiniStat(label: "Edit", value: "↗", useMono: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .contentShape(Rectangle())
        .brutalistTap {
            Haptics.rigid()
            onEdit(CourseDraft.from(course))
        }
    }

    private var footerLine: some View {
        HStack {
            Text("END OF ARCHIVE")
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

    // MARK: - Helpers

    private func headerLine(_ course: Course) -> String {
        let date = Self.dateFormatter.string(from: course.createdAt).uppercased()
        return "ADDED \(date)"
    }

    private func subline(_ course: Course) -> String {
        var parts: [String] = []
        if let loc = course.location, !loc.isEmpty {
            parts.append(loc.uppercased())
        }
        if course.holes.isEmpty {
            parts.append("NO HOLES")
        } else {
            let par = course.holes.reduce(0) { $0 + $1.par }
            parts.append("PAR \(par)")
        }
        return parts.joined(separator: " · ")
    }

    private func referenceCode(_ course: Course) -> String {
        let initials = course.name.split(separator: " ").prefix(3).compactMap { $0.first }
        let prefix = String(initials).uppercased().padding(toLength: 3, withPad: "X", startingAt: 0)
        let suffix = String(course.externalId.uuidString.replacingOccurrences(of: "-", with: "").suffix(4)).uppercased()
        return "\(prefix)-\(suffix)"
    }

    private func bestScore(_ course: Course) -> String {
        // Reads from the shared default aggregate filter (18-hole Stroke /
        // Stableford / Match) so scrambles, 9-hole rounds, and historical
        // missing-format rounds don't get crowned as the course best.
        // Courses without an eligible round display the standard fallback.
        eligibleBests[course.externalId].map(String.init) ?? "—"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yy"
        return f
    }()

    @MainActor
    private func reload() async {
        isRefreshing = true
        defer { isRefreshing = false }
        async let fetchedCourses = try? await coursesRepository.fetchAll()
        async let fetchedBests = try? await roundsRepository.bestScoresByCourse(filter: .default)
        let courses = await fetchedCourses
        let bests = await fetchedBests
        if let courses {
            withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                self.courses = courses.sorted { $0.createdAt > $1.createdAt }
                self.eligibleBests = bests ?? [:]
            }
        }
    }
}
