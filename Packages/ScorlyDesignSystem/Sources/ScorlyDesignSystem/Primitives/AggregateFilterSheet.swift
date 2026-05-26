import SwiftUI

/// Bottom-sheet body for picking aggregate eligibility (holes / format /
/// round type / tees) and an optional sample-window choice. Raw-string
/// parameterised so the DesignSystem can stay free of domain imports —
/// each host feature converts to/from its typed filter model.
///
/// Selection semantics: an empty `Set<String>` for a category means
/// "include all values for that category", matching the brief's rule.
public struct AggregateFilterSheet: View {
    public struct Group: Identifiable {
        public let id: String
        public let label: String
        public let options: [String]
        public let selection: Binding<Set<String>>

        public init(id: String, label: String, options: [String], selection: Binding<Set<String>>) {
            self.id = id
            self.label = label
            self.options = options
            self.selection = selection
        }
    }

    public struct SingleSelectGroup: Identifiable {
        public let id: String
        public let label: String
        public let options: [String]
        public let selection: Binding<String>

        public init(id: String, label: String, options: [String], selection: Binding<String>) {
            self.id = id
            self.label = label
            self.options = options
            self.selection = selection
        }
    }

    private let groups: [Group]
    private let singleSelect: SingleSelectGroup?
    private let recordCount: Int
    private let onApply: () -> Void
    private let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        groups: [Group],
        singleSelect: SingleSelectGroup? = nil,
        recordCount: Int,
        onApply: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.groups = groups
        self.singleSelect = singleSelect
        self.recordCount = recordCount
        self.onApply = onApply
        self.onReset = onReset
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabHandle
                    header
                    HBar(vMargin: BrutalistSpacing.m)
                    ForEach(groups) { group in
                        groupView(group)
                    }
                    if let singleSelect {
                        singleSelectView(singleSelect)
                    }
                }
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.s)
                .padding(.bottom, BrutalistSpacing.m)
            }
            footer
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.m)
                .padding(.bottom, BrutalistSpacing.m)
                .background(BrutalistColor.bg)
        }
        .background(BrutalistColor.bg)
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.fraction(0.8)])
        .presentationDragIndicator(.hidden)
    }

    private var grabHandle: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 44, height: 3)
            Spacer()
        }
        .padding(.bottom, BrutalistSpacing.s)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FILTER")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text("\(recordCount) MATCHING")
                    .font(BrutalistType.sheetTitle)
                    .kerning(-0.6)
                    .monospacedDigit()
            }
            Spacer()
            Text("CLOSE ✕")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap { dismiss() }
        }
    }

    private func groupView(_ group: Group) -> some View {
        Section(label: group.label) {
            ChipGridMulti(
                options: group.options,
                selection: group.selection,
                columns: columnCount(for: group.options.count)
            )
        }
    }

    private func singleSelectView(_ group: SingleSelectGroup) -> some View {
        Section(label: group.label) {
            ChipGrid(
                options: group.options,
                selection: Binding(
                    get: { group.selection.wrappedValue },
                    set: { newValue in
                        guard let newValue else { return }
                        group.selection.wrappedValue = newValue
                    }
                ),
                columns: columnCount(for: group.options.count),
                allowsDeselect: false
            )
        }
    }

    private func columnCount(for optionCount: Int) -> Int {
        if optionCount <= 2 { return 2 }
        if optionCount <= 3 { return 3 }
        return 4
    }

    private var footer: some View {
        HStack(spacing: 8) {
            BrutalistButton(
                kind: .ghost,
                action: {
                    Haptics.light()
                    onReset()
                },
                padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
            ) {
                Text("RESET")
                    .font(BrutalistType.mono(.semibold, size: 12))
                    .kerning(1.0)
            } caption: {
                EmptyView()
            }
            BrutalistButton(
                kind: .fg,
                action: {
                    Haptics.light()
                    onApply()
                    dismiss()
                },
                padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
            ) {
                Text("APPLY")
                    .font(BrutalistType.sans(.bold, size: 14))
                    .kerning(0.4)
            } caption: {
                EmptyView()
            }
        }
    }
}
