import SwiftUI

/// Brutalist date control. Renders a bordered trigger row showing the
/// current date in mono uppercase; tapping opens a sheet with a wheel
/// `DatePicker` so the system day grid never leaks through the bone
/// palette.
public struct BrutalistDateField: View {
    @Binding private var value: Date
    @State private var showSheet = false

    public init(value: Binding<Date>) {
        _value = value
    }

    public var body: some View {
        HStack {
            Text(Self.format(value))
                .font(BrutalistType.mono(.semibold, size: 13))
                .kerning(0.8)
            Spacer()
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrutalistColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .contentShape(Rectangle())
        .brutalistTap {
            Haptics.light()
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            sheetBody
        }
    }

    private var sheetBody: some View {
        VStack(spacing: 0) {
            Text("DATE PLAYED")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.xl)

            wheelPicker
                .frame(maxWidth: .infinity)
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.m)

            Spacer(minLength: 0)

            BrutalistButton(
                kind: .fg,
                action: { showSheet = false },
                padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
            ) {
                Text("DONE")
                    .font(BrutalistType.sans(.bold, size: 15))
                    .kerning(0.4)
            }
            .padding(.horizontal, BrutalistSpacing.pageHorizontal)
            .padding(.bottom, BrutalistSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var wheelPicker: some View {
        #if os(iOS)
        DatePicker(
            "",
            selection: $value,
            displayedComponents: [.date]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .tint(BrutalistColor.fg)
        #else
        DatePicker(
            "",
            selection: $value,
            displayedComponents: [.date]
        )
        .labelsHidden()
        .tint(BrutalistColor.fg)
        #endif
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}
