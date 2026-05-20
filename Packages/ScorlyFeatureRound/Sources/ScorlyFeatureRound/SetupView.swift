import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Brutalist round setup. Ten ordered sections (01 — Course through
/// 10 — Notes). Binds to a `RoundSetupForm` the parent owns.
public struct SetupView: View {
    @Binding private var form: RoundSetupForm
    private let courses: [Course]
    private let onCancel: () -> Void
    private let onTeeOff: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        form: Binding<RoundSetupForm>,
        courses: [Course],
        onCancel: @escaping () -> Void,
        onTeeOff: @escaping () -> Void
    ) {
        _form = form
        self.courses = courses
        self.onCancel = onCancel
        self.onTeeOff = onTeeOff
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "ROUND SETUP", right: "SCORLY/B  ®")

            HStack {
                Text("← CANCEL")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                    .brutalistTap(action: onCancel)
                Spacer()
                Text("NEW ROUND")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.l)

            VStack(alignment: .leading, spacing: 0) {
                (
                    Text("Set up\n")
                        .font(BrutalistType.pageHero)
                        .kerning(-1.8)
                        .foregroundColor(BrutalistColor.fg)
                    + Text("the round.")
                        .font(BrutalistType.pageHero)
                        .kerning(-1.8)
                        .foregroundColor(BrutalistColor.fg)
                )
                .lineLimit(3)
                Text("COURSE · FORMAT · CONDITIONS · LOGISTICS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                    .padding(.top, BrutalistSpacing.xs)
            }
            .padding(.top, BrutalistSpacing.md)

            HBar(vMargin: BrutalistSpacing.xl)

            coursePicker
            teeSelector
            holesSelector
            roundTypeSection
            formatSection
            conditionsSection
            logisticsSection
            playersSection
            mentalStateSection
            notesSection

            HBar(vMargin: BrutalistSpacing.xl)

            BrutalistButton(
                kind: .fg,
                action: onTeeOff,
                isDisabled: !form.isReady,
                padding: EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
            ) {
                Text("TEE OFF →")
                    .font(BrutalistType.sans(.bold, size: 17))
            } caption: {
                Text(teeOffCaption)
                    .font(BrutalistType.monoCaption)
                    .kerning(1.2)
            }
        }
    }

    private var teeOffCaption: String {
        switch form.holesPlayed {
        case .back9: "HOLE 10"
        case .front9, .eighteen: "HOLE 01"
        }
    }

    // MARK: - 01 Course

    private var coursePicker: some View {
        let courseIdx = currentCourseIndex
        return Section(label: "01 — Course   /   \(String(format: "%02d", courseIdx + 1)) OF \(String(format: "%02d", max(courses.count, 1)))") {
            if courses.isEmpty {
                emptyCoursesPanel
            } else {
                courseCard(index: courseIdx)
                dotPagination(active: courseIdx, count: courses.count)
            }
        }
    }

    private var emptyCoursesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NO COURSES YET")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Text("Add a course before you tee off.")
                .font(BrutalistType.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func courseCard(index: Int) -> some View {
        let course = courses[index]
        let tee = activeTee(for: course)
        let yardage = yardageInRange(tee)
        let par = parInRange(course)
        let slope = tee?.slopeRating.map { Self.intString($0) } ?? "—"
        let rating = tee?.courseRating.map { Self.oneDecimal($0) } ?? "—"
        return HStack(alignment: .center, spacing: 0) {
            pickerArrow(direction: .left, action: { cycleCourse(by: -1) })
            ZStack {
                CornerMarks(size: 6, inset: 4)
                VStack(alignment: .leading, spacing: 0) {
                    Text(course.name)
                        .font(BrutalistType.pickerTitle)
                        .kerning(-0.4)
                    Text((course.location ?? "—").uppercased())
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                        .padding(.top, BrutalistSpacing.xxs)
                    HStack(spacing: 4) {
                        Mini(label: "Par", value: "\(par)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Mini(label: "Slope", value: slope)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Mini(label: "Rating", value: rating)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Mini(label: "Yards", value: yardage.map { "\($0)" } ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, BrutalistSpacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity)
            .background(BrutalistColor.panel)
            pickerArrow(direction: .right, action: { cycleCourse(by: 1) })
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func activeTee(for course: Course) -> Tee? {
        course.tees.first(where: { $0.id == form.teeId }) ?? course.tees.first
    }

    private func holeRange() -> ClosedRange<Int> {
        switch form.holesPlayed {
        case .front9: return 1...9
        case .back9: return 10...18
        case .eighteen: return 1...18
        }
    }

    private func parInRange(_ course: Course) -> Int {
        let r = holeRange()
        return course.holes.filter { r.contains($0.number) }.reduce(0) { $0 + $1.par }
    }

    private func yardageInRange(_ tee: Tee?) -> Int? {
        guard let tee else { return nil }
        let r = holeRange()
        let subset = tee.teeHoles.filter { r.contains($0.holeNumber) }
        guard !subset.isEmpty else {
            return form.holesPlayed == .eighteen ? tee.totalYardage : nil
        }
        return subset.reduce(0) { $0 + $1.yardage }
    }

    private enum ArrowDirection { case left, right }

    private func pickerArrow(direction: ArrowDirection, action: @escaping () -> Void) -> some View {
        Text(direction == .left ? "←" : "→")
            .font(BrutalistType.mono(.semibold, size: 18))
            .foregroundStyle(BrutalistColor.fg)
            .frame(width: 44, height: 76)
            .overlay(alignment: direction == .left ? .trailing : .leading) {
                Rectangle().fill(BrutalistColor.rule).frame(width: 1)
            }
            .brutalistTap {
                Haptics.light()
                action()
            }
    }

    private func dotPagination(active: Int, count: Int) -> some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            ForEach(0..<count, id: \.self) { index in
                Rectangle()
                    .fill(index == active ? BrutalistColor.fg : BrutalistColor.hair)
                    .frame(width: index == active ? 18 : 6, height: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, BrutalistSpacing.xs)
    }

    private func cycleCourse(by delta: Int) {
        guard !courses.isEmpty else { return }
        let next = (currentCourseIndex + delta + courses.count) % courses.count
        let course = courses[next]
        form.courseId = course.id
        // Reset tee if it doesn't belong to the new course.
        if !course.tees.contains(where: { $0.id == form.teeId }) {
            form.teeId = course.tees.first?.id
        }
    }

    private var currentCourseIndex: Int {
        guard let courseId = form.courseId else { return 0 }
        return courses.firstIndex(where: { $0.id == courseId }) ?? 0
    }

    // MARK: - 02 Tees

    private var teeSelector: some View {
        Section(label: "02 — Tees") {
            let course = courses.indices.contains(currentCourseIndex) ? courses[currentCourseIndex] : nil
            let tees = course?.tees ?? []
            if tees.isEmpty {
                Text("NO TEES DEFINED")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: max(min(tees.count, 4), 1)), spacing: 6) {
                    ForEach(tees) { tee in
                        teeButton(tee: tee, isActive: form.teeId == tee.id)
                    }
                }
            }
        }
    }

    private func teeButton(tee: Tee, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Self.teeColor(for: tee.name))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(isActive ? BrutalistColor.bg : BrutalistColor.rule, lineWidth: 1))
            Text(tee.name.uppercased())
                .font(BrutalistType.mono(.semibold, size: 10))
                .kerning(0.8)
            if let yardage = tee.totalYardage {
                Text("\(yardage)y")
                    .font(BrutalistType.mono(.regular, size: 8))
                    .opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(isActive ? BrutalistColor.fg : .clear)
        .foregroundStyle(isActive ? BrutalistColor.bg : BrutalistColor.fg)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .brutalistTap {
            Haptics.light()
            form.teeId = tee.id
        }
    }

    /// Tee color heuristic — derived from the tee name. The brutalist
    /// design uses this as a data signal, not as an accent color.
    private static func teeColor(for name: String) -> Color {
        switch name.lowercased() {
        case "black", "championship": Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
        case "blue", "tournament", "members": Color(red: 0x3F / 255, green: 0x4F / 255, blue: 0x66 / 255)
        case "white", "regular": Color(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xE9 / 255)
        case "red", "forward", "ladies": Color(red: 0x8A / 255, green: 0x4A / 255, blue: 0x40 / 255)
        case "gold", "senior": Color(red: 0xC9 / 255, green: 0xA8 / 255, blue: 0x4F / 255)
        case "green": Color(red: 0x4A / 255, green: 0x6A / 255, blue: 0x4A / 255)
        default: BrutalistColor.dim
        }
    }

    // MARK: - 03 Holes

    private var holesSelector: some View {
        Section(label: "03 — Holes") {
            let options: [(HolesPlayed, String, String)] = [
                (.front9, "Front 9", "HOLES 01–09"),
                (.back9, "Back 9", "HOLES 10–18"),
                (.eighteen, "18", "FULL ROUND"),
            ]
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { value, label, sub in
                    let active = form.holesPlayed == value
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label)
                            .font(BrutalistType.sans(.bold, size: 22))
                            .kerning(-0.6)
                        Text(sub)
                            .font(BrutalistType.monoMicro)
                            .kerning(0.6)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 10)
                    .background(active ? BrutalistColor.fg : .clear)
                    .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                    .brutalistTap {
                        Haptics.light()
                        form.holesPlayed = value
                    }
                }
            }
        }
    }

    // MARK: - 04 Round Type / 05 Format

    private var roundTypeSection: some View {
        Section(label: "04 — Round Type") {
            ChipGrid(
                options: RoundType.allCases.map(\.rawValue),
                selection: Binding(
                    get: { form.roundType?.rawValue },
                    set: { form.roundType = $0.flatMap(RoundType.init(rawValue:)) }
                ),
                columns: 2,
                allowsDeselect: false
            )
        }
    }

    private var formatSection: some View {
        Section(label: "05 — Format") {
            ChipGrid(
                options: RoundFormat.allCases.map(\.rawValue),
                selection: Binding(
                    get: { form.roundFormat?.rawValue },
                    set: { form.roundFormat = $0.flatMap(RoundFormat.init(rawValue:)) }
                ),
                columns: 3,
                allowsDeselect: false
            )
        }
    }

    // MARK: - 06 Conditions + Temperature

    private var conditionsSection: some View {
        Section(label: "06 — Conditions") {
            ChipGridMulti(
                options: Conditions.labeledFlags.map(\.label),
                selection: Binding(
                    get: { conditionsAsLabels(form.conditions) },
                    set: { form.conditions = conditionsFromLabels($0) }
                ),
                columns: 4
            )
            temperatureRow
                .padding(.top, BrutalistSpacing.s)
        }
    }

    private var temperatureRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TEMPERATURE")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(form.temperature)")
                        .font(BrutalistType.mediumValue)
                        .kerning(-0.8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("°")
                        .font(BrutalistType.rowTitle)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                SmallStep("−") {
                    if form.temperature > -20 {
                        withAnimation(Motion.snap) { form.temperature -= 1 }
                    }
                }
                SmallStep("+") {
                    if form.temperature < 50 {
                        withAnimation(Motion.snap) { form.temperature += 1 }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func conditionsAsLabels(_ value: Conditions) -> Set<String> {
        Set(Conditions.labeledFlags.compactMap { value.contains($0.flag) ? $0.label : nil })
    }

    private func conditionsFromLabels(_ labels: Set<String>) -> Conditions {
        Conditions.labeledFlags.reduce(into: Conditions()) { partial, entry in
            if labels.contains(entry.label) { partial.formUnion(entry.flag) }
        }
    }

    // MARK: - 07 Logistics

    private var logisticsSection: some View {
        Section(label: "07 — Logistics") {
            VStack(spacing: 6) {
                dateField
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(WalkingVsRiding.allCases, id: \.rawValue) { option in
                        let active = form.walkingVsRiding == option
                        Text(option.rawValue.uppercased())
                            .font(BrutalistType.mono(.semibold, size: 10))
                            .kerning(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .background(active ? BrutalistColor.fg : .clear)
                            .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                            .brutalistTap {
                                Haptics.light()
                                form.walkingVsRiding = option
                            }
                    }
                }
            }
        }
    }

    private var dateField: some View {
        FieldBox(label: "Date") {
            BrutalistDateField(value: $form.datePlayed)
        }
    }

    // MARK: - 08 Players

    private var playersSection: some View {
        Section(label: "08 — Players") {
            VStack(spacing: 6) {
                ForEach(Array(form.players.enumerated()), id: \.element.id) { item in
                    PlayerRowView(
                        displayNumber: item.offset + 1,
                        player: $form.players[item.offset],
                        canDelete: item.offset > 0,
                        onDelete: { form.players.remove(at: item.offset) }
                    )
                }
                if form.players.count < 4 {
                    HStack {
                        Text("+  ADD PLAYER")
                        Spacer()
                        Text("\(form.players.count)/4")
                            .foregroundStyle(BrutalistColor.muted)
                    }
                    .font(BrutalistType.monoCaption)
                    .kerning(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(BrutalistColor.fg)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .brutalistTap {
                        Haptics.light()
                        let next = form.players.count
                        form.players.append(.init(name: "Guest \(next)", handicap: 18))
                    }
                }
            }
        }
    }

    // playerRow and playerNameField replaced by PlayerRowView + HCPField below

    // MARK: - 09 Mental State

    private var mentalStateSection: some View {
        Section(label: "09 — Mental State") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HOW ARE YOU FEELING? (1–10)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    Text("\(form.mentalState)")
                        .font(BrutalistType.mediumValue)
                        .kerning(-1)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                BrutalistSlider(
                    value: $form.mentalState,
                    in: 1...10
                )
                .padding(.top, BrutalistSpacing.sm)
                HStack {
                    Text("DISTRACTED")
                    Spacer()
                    Text("LOCKED IN")
                }
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
                .padding(.top, BrutalistSpacing.xxs)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    // MARK: - 10 Notes

    private var notesSection: some View {
        Section(label: "10 — Notes") {
            TextEditor(text: $form.notes)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(10)
                .font(BrutalistType.inputBody)
                .foregroundStyle(BrutalistColor.fg)
                .background(BrutalistColor.bg)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    // MARK: - Formatters

    private static func oneDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }

    private static func intString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}

// MARK: - Player row

private struct PlayerRowView: View {
    let displayNumber: Int
    @Binding var player: RoundSetupForm.Player
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0
    private let deleteWidth: CGFloat = 52

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button {
                    withAnimation(Motion.snap) { swipeOffset = 0 }
                    Haptics.soft()
                    onDelete()
                } label: {
                    Text("×")
                        .font(BrutalistType.mono(.semibold, size: 22))
                        .foregroundStyle(BrutalistColor.bg)
                        .frame(width: deleteWidth)
                        .frame(maxHeight: .infinity)
                        .background(BrutalistColor.fg)
                }
                .buttonStyle(.plain)
            }

            if canDelete {
                rowContent
                    .offset(x: swipeOffset)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                guard value.translation.width < 0 else { return }
                                swipeOffset = max(-deleteWidth, value.translation.width)
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    swipeOffset = -value.translation.width > deleteWidth / 2
                                        ? -deleteWidth : 0
                                }
                            }
                    )
            } else {
                rowContent
            }
        }
        .clipped()
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text("\(displayNumber)")
                .font(BrutalistType.mono(.medium, size: 10))
                .frame(width: 22, height: 22)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))

            nameField

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Text("HCP")
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                HCPField(handicap: $player.handicap)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(BrutalistColor.bg)
    }

    @ViewBuilder
    private var nameField: some View {
        let binding = Binding(
            get: { player.name },
            set: { player.name = $0 }
        )
        #if os(iOS)
        TextField("Name", text: binding)
            .font(BrutalistType.body)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
        #else
        TextField("Name", text: binding)
            .font(BrutalistType.body)
        #endif
    }
}

// MARK: - HCP text field

private struct HCPField: View {
    @Binding var handicap: Decimal
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        textField
            .font(BrutalistType.mono(.semibold, size: 12))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 44, alignment: .trailing)
            .focused($isFocused)
            .onAppear { text = format(handicap) }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: handicap) { _, value in
                if !isFocused { text = format(value) }
            }
    }

    @ViewBuilder
    private var textField: some View {
        #if os(iOS)
        TextField("0.0", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .submitLabel(.done)
            .onSubmit { commit() }
        #else
        TextField("0.0", text: $text)
            .onSubmit { commit() }
        #endif
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let d = Decimal(string: trimmed),
           d >= Decimal(-10), d <= Decimal(54) {
            handicap = d
        }
        text = format(handicap)
    }

    private func format(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: value as NSDecimalNumber) ?? "0.0"
    }
}
