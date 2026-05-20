import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Add / Edit course screen. Editable fields: name, location, notes.
/// On save, persists via the repository — for new drafts a standard
/// par-72 graph is generated under the hood. Delete shows up only when
/// editing an existing course; a two-step "tap to arm, tap to confirm"
/// pattern keeps destructive actions a deliberate move without a
/// modal alert (DESIGN.md bans modal-as-first-thought).
public struct CourseEditorView: View {
    let coursesRepository: any CoursesRepository
    let userId: UUID
    let initial: CourseDraft
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var draft: CourseDraft
    @State private var isSaving = false
    @State private var deleteArmed = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable { case name, location, notes }

    public init(
        coursesRepository: any CoursesRepository,
        userId: UUID,
        initial: CourseDraft,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.coursesRepository = coursesRepository
        self.userId = userId
        self.initial = initial
        self.onCancel = onCancel
        self.onSaved = onSaved
        _draft = State(initialValue: initial)
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: topBarLeft, right: "SCORLY/B  ®")
            HairlineProgress(isLoading: isSaving)
                .padding(.top, BrutalistSpacing.s)
            backRow
                .padding(.top, BrutalistSpacing.m)
            hero
                .padding(.top, BrutalistSpacing.m)
            tagline

            form
                .padding(.top, BrutalistSpacing.l)

            saveCta
                .padding(.top, BrutalistSpacing.l)

            if draft.isEditingExisting {
                deleteRow
                    .padding(.top, BrutalistSpacing.m)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(BrutalistType.inputBody)
                    .foregroundStyle(BrutalistColor.fg)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                    .padding(.top, BrutalistSpacing.m)
            }

            footerLine
                .padding(.top, BrutalistSpacing.xl)
                .padding(.bottom, BrutalistSpacing.xl)
        }
    }

    // MARK: - Sub-views

    private var topBarLeft: String {
        draft.isEditingExisting ? "EDIT COURSE" : "ADD COURSE"
    }

    private var backRow: some View {
        HStack {
            Text("← BACK")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap {
                    Haptics.rigid()
                    onCancel()
                }
            Spacer()
            Text(draft.isEditingExisting ? "EDITING RECORD" : "NEW RECORD")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var hero: some View {
        Text(draft.isEditingExisting ? "Refine\nthe card." : "New\nlayout.")
            .font(BrutalistType.sans(.bold, size: 44))
            .kerning(-1.8)
            .lineSpacing(-4)
            .foregroundStyle(BrutalistColor.fg)
            .padding(.bottom, BrutalistSpacing.xs)
    }

    private var tagline: some View {
        Text(draft.isEditingExisting
                ? "EDIT METADATA · HOLES + TEES PRESERVED"
                : "NAME · LOCATION · NOTES · STANDARD PAR 72")
            .font(BrutalistType.monoLabel)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
    }

    private var form: some View {
        VStack(spacing: 10) {
            FieldBox(label: "Course Name") {
                #if os(iOS)
                TextField("e.g. Manila Southwoods", text: $draft.name)
                    .font(BrutalistType.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focused, equals: .name)
                    .onSubmit { focused = .location }
                #else
                TextField("e.g. Manila Southwoods", text: $draft.name)
                    .font(BrutalistType.body)
                #endif
            }
            FieldBox(label: "Location") {
                #if os(iOS)
                TextField("City, Country", text: $draft.location)
                    .font(BrutalistType.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focused, equals: .location)
                    .onSubmit { focused = .notes }
                #else
                TextField("City, Country", text: $draft.location)
                    .font(BrutalistType.body)
                #endif
            }
            FieldBox(label: "Notes") {
                #if os(iOS)
                TextField("Optional", text: $draft.notes, axis: .vertical)
                    .font(BrutalistType.body)
                    .lineLimit(2...4)
                    .submitLabel(.done)
                    .focused($focused, equals: .notes)
                    .onSubmit { focused = nil }
                #else
                TextField("Optional", text: $draft.notes, axis: .vertical)
                    .font(BrutalistType.body)
                    .lineLimit(2...4)
                #endif
            }
        }
    }

    private var saveCta: some View {
        BrutalistButton(
            kind: .fg,
            action: save,
            isDisabled: !draft.isValid || isSaving,
            padding: EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
        ) {
            Text(draft.isEditingExisting ? "Save changes" : "Add course")
                .font(BrutalistType.sans(.bold, size: 18))
                .kerning(-0.3)
        } caption: {
            Text(isSaving ? "WAIT" : "→ FILE")
                .font(BrutalistType.monoCaption)
                .kerning(1.2)
        }
    }

    /// Two-step delete: first tap arms (shifts the row to "TAP AGAIN
    /// TO CONFIRM"), second tap commits. No modal, no alert.
    private var deleteRow: some View {
        HStack {
            Text(deleteArmed ? "TAP AGAIN TO CONFIRM" : "DELETE THIS COURSE")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(deleteArmed ? BrutalistColor.invFg : BrutalistColor.fg)
            Spacer()
            Text(deleteArmed ? "⌫  REMOVE" : "⌫  ARM")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(deleteArmed ? BrutalistColor.invFg : BrutalistColor.fg)
        }
        .padding(14)
        .background(deleteArmed ? BrutalistColor.fg : Color.clear)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .contentShape(Rectangle())
        .brutalistTap {
            withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                if deleteArmed {
                    Task { await performDelete() }
                } else {
                    deleteArmed = true
                    Haptics.light()
                }
            }
        }
    }

    private var footerLine: some View {
        HStack {
            Text(draft.isEditingExisting ? "RECORD EDIT" : "NEW RECORD")
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

    // MARK: - Actions

    private func save() {
        guard draft.isValid, !isSaving else { return }
        focused = nil
        isSaving = true
        errorMessage = nil
        Haptics.rigid()
        let course = draft.commit(userId: userId)
        let existed = draft.isEditingExisting
        Task {
            do {
                if existed {
                    try await coursesRepository.update(course)
                } else {
                    try await coursesRepository.save(course)
                }
                await MainActor.run {
                    isSaving = false
                    onSaved()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Save failed. \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func performDelete() async {
        guard let existing = draft.existing else { return }
        isSaving = true
        errorMessage = nil
        Haptics.rigid()
        do {
            try await coursesRepository.delete(id: existing.id)
            isSaving = false
            onSaved()
        } catch {
            isSaving = false
            deleteArmed = false
            errorMessage = "Delete failed. \(error.localizedDescription)"
        }
    }
}
