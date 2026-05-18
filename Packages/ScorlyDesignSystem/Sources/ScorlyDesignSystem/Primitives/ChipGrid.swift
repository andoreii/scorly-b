import SwiftUI

/// Grid of mono-uppercase choice chips. Single-select.
public struct ChipGrid: View {
    private let options: [String]
    @Binding private var selection: String?
    private let columns: Int
    private let allowsDeselect: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        options: [String],
        selection: Binding<String?>,
        columns: Int = 3,
        allowsDeselect: Bool = true
    ) {
        self.options = options
        _selection = selection
        self.columns = columns
        self.allowsDeselect = allowsDeselect
    }

    public var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(options, id: \.self) { option in
                let active = selection == option
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        if active, allowsDeselect {
                            selection = nil
                        } else {
                            selection = option
                        }
                    }
                } label: {
                    Text(option.uppercased())
                        .font(BrutalistType.monoCaption)
                        .kerning(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(active ? BrutalistColor.fg : .clear)
                        .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Multi-select variant — used for conditions in Round Setup.
public struct ChipGridMulti: View {
    private let options: [String]
    @Binding private var selection: Set<String>
    private let columns: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(options: [String], selection: Binding<Set<String>>, columns: Int = 4) {
        self.options = options
        _selection = selection
        self.columns = columns
    }

    public var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(options, id: \.self) { option in
                let active = selection.contains(option)
                Button {
                    Haptics.light()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        if active { selection.remove(option) } else { selection.insert(option) }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(option.uppercased())
                            .font(BrutalistType.monoCaption)
                            .kerning(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        if active {
                            Text("×")
                                .font(BrutalistType.mono(.medium, size: 8))
                                .padding(4)
                        }
                    }
                    .background(active ? BrutalistColor.fg : .clear)
                    .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
