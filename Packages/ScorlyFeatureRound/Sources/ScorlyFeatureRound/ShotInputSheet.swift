import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// The rising input sheet. Tapping a Thread node raises this over a
/// dimmed hole: a tap-to-place `TargetField`, a drag `DistanceDial`, a
/// club button, and per-mode shortcuts (hazard tags / pin position /
/// holed-out / add-putt). Every edit routes through `RoundPlayState`'s
/// slot helpers, which write the existing `HoleEntry` fields. Mirrors the
/// React `RPIShotSheet`, extended with the holed-out and pin controls.
struct ShotInputSheet: View {
    @Bindable var state: RoundPlayState
    let node: RoundPlayState.ThreadNode
    let total: Int
    let prevSlot: RoundPlayState.ShotSlot?
    let nextSlot: RoundPlayState.ShotSlot?
    let onSelect: (RoundPlayState.ShotSlot) -> Void
    let onClose: () -> Void

    @State private var clubOpen = false

    private var slot: RoundPlayState.ShotSlot {
        node.slot
    }

    private var isPutt: Bool {
        node.mode == .putt
    }

    private var idx: Int {
        state.holeIdx
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            panel
                .background(BrutalistColor.bg)
                .overlay(alignment: .top) { Rectangle().fill(BrutalistColor.fg).frame(height: 1.8) }
                .transition(.move(edge: .bottom))

            if clubOpen {
                ClubKeypadSheet(club: clubBinding) { clubOpen = false }
            }
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            grabberHeader
            TargetField(mode: node.mode, placement: node.placement) { pick in
                state.applyPick(pick, to: slot, at: idx)
            }
            .frame(height: 280)
            .padding(.horizontal, 8)

            if node.mode == .green {
                pinRow
            }

            if isPutt { puttActions } else { shotActions }

            dialRow
            footer
        }
    }

    // MARK: - Header

    private var grabberHeader: some View {
        VStack(spacing: 10) {
            Rectangle().fill(BrutalistColor.hair).frame(width: 36, height: 4)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SHOT \(String(format: "%02d", node.displayIndex)) · \(node.title.uppercased())")
                        .font(BrutalistType.mono(.semibold, size: 9.5))
                        .kerning(1.1)
                    if node.logged, let label = node.resultLabel {
                        resultChip(label, good: node.good)
                    } else {
                        Text(isPutt ? "TAP WHERE IT FINISHED →" : "TAP TARGET →")
                            .font(BrutalistType.mono(.medium, size: 8.5))
                            .kerning(1)
                            .foregroundStyle(BrutalistColor.dim)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(node.distanceSubtitle.uppercased()) · \(isPutt ? "FEET" : "YARDS")")
                        .font(BrutalistType.mono(.medium, size: 7.5))
                        .kerning(1)
                        .foregroundStyle(BrutalistColor.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(dialValue)")
                            .font(BrutalistType.mediumValue)
                            .kerning(-1.5)
                            .monospacedDigit()
                        Text(isPutt ? "FT" : "YDS")
                            .font(BrutalistType.mono(.semibold, size: 10))
                            .foregroundStyle(BrutalistColor.muted)
                    }
                }
                Text("✕")
                    .font(BrutalistType.mono(.medium, size: 15))
                    .foregroundStyle(BrutalistColor.muted)
                    .brutalistTap(action: onClose)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(BrutalistColor.hair).frame(height: 1) }
    }

    // MARK: - Pin (green mode)

    private var pinRow: some View {
        HStack(spacing: 8) {
            Text("PIN")
                .font(BrutalistType.mono(.medium, size: 8))
                .kerning(1.2)
                .foregroundStyle(BrutalistColor.muted)
            PinSelect(value: pinBinding)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private var shotActions: some View {
        HStack(spacing: 6) {
            ForEach(HazardTag.allCases, id: \.self) { tag in
                hazardButton(tag)
            }
            if node.mode == .green {
                actionButton("HOLED ✓", filled: node.good, accent: true) {
                    let wasHoled = node.good
                    state.holeOutShot(slot, at: idx)
                    if !wasHoled { onClose() }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var puttActions: some View {
        HStack(spacing: 6) {
            actionButton("MISSED · ADD PUTT", filled: false, accent: false) {
                state.addPutt(after: slot, at: idx)
                if let next = nextSlot { onSelect(next) }
            }
            actionButton("HOLED ✓", filled: node.good, accent: true) {
                let pick = TargetField.Pick(
                    value: nil,
                    pos: CGPoint(x: 0.5, y: 0.493),
                    good: true,
                    label: "HOLED",
                    proximityFeet: 0,
                    holed: true
                )
                state.applyPick(pick, to: slot, at: idx)
                onClose()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func hazardButton(_ tag: HazardTag) -> some View {
        let on = hazardActive(tag)
        return Text(tag.rawValue.uppercased())
            .font(BrutalistType.mono(.semibold, size: 9))
            .kerning(0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(on ? BrutalistColor.fg : .clear)
            .foregroundStyle(on ? BrutalistColor.bg : BrutalistColor.muted)
            .overlay(Rectangle().stroke(on ? BrutalistColor.fg : BrutalistColor.hair, lineWidth: 1.3))
            .brutalistTap {
                Haptics.light()
                state.applyHazard(tag, to: slot, at: idx)
            }
    }

    private func actionButton(_ label: String, filled: Bool, accent: Bool, action: @escaping () -> Void) -> some View {
        let border = accent ? BrutalistColor.acc : BrutalistColor.fg
        return Text(label)
            .font(BrutalistType.mono(.semibold, size: 9.5))
            .kerning(0.6)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(filled ? border : .clear)
            .foregroundStyle(filled ? BrutalistColor.bg : border)
            .overlay(Rectangle().stroke(border, lineWidth: 1.3))
            .brutalistTap {
                Haptics.medium()
                action()
            }
    }

    // MARK: - Dial + club

    private var dialRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("↔ DISTANCE DIAL · DRAG TO SET \(node.distanceSubtitle.uppercased())")
                    .font(BrutalistType.mono(.medium, size: 7))
                    .kerning(1.2)
                    .foregroundStyle(BrutalistColor.dim)
                DistanceDial(value: dialBinding, unit: node.unit)
            }
            if state.slotHasClub(slot) {
                clubButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .top) { Rectangle().fill(BrutalistColor.hair).frame(height: 1) }
    }

    private var clubButton: some View {
        VStack(spacing: 1) {
            Text("CLUB")
                .font(BrutalistType.mono(.medium, size: 6.5))
                .kerning(1)
                .opacity(0.7)
            Text((state.slotClub(slot, at: idx) ?? "—").uppercased())
                .font(BrutalistType.mono(.semibold, size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 58, height: 58)
        .background(BrutalistColor.fg)
        .foregroundStyle(BrutalistColor.bg)
        .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 1.4))
        .brutalistTap {
            Haptics.light()
            clubOpen = true
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 7) {
            navButton("‹ PREV SHOT", enabled: prevSlot != nil) {
                if let prev = prevSlot { onSelect(prev) }
            }
            navButton("DONE", enabled: true, fill: BrutalistColor.panel, action: onClose)
            navButton("NEXT SHOT ›", enabled: nextSlot != nil) {
                if let next = nextSlot { onSelect(next) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    private func navButton(
        _ label: String,
        enabled: Bool,
        fill: Color = .clear,
        action: @escaping () -> Void
    ) -> some View {
        Text(label)
            .font(BrutalistType.mono(.semibold, size: 10))
            .kerning(1)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(fill)
            .foregroundStyle(enabled ? BrutalistColor.fg : BrutalistColor.dim)
            .overlay(Rectangle().stroke(enabled ? BrutalistColor.fg : BrutalistColor.hair, lineWidth: 1.4))
            .opacity(enabled ? 1 : 0.5)
            .brutalistTap(disabled: !enabled) {
                Haptics.light()
                action()
            }
    }

    // MARK: - Bindings & helpers

    private var dialValue: Int {
        state.slotDistance(slot, at: idx) ?? defaultDistance
    }

    private var defaultDistance: Int {
        switch node.mode {
        case .putt: return 6
        case .fairway: return 240
        case .green:
            if case .chip = slot { return 20 }
            return 150
        }
    }

    private var dialBinding: Binding<Int> {
        Binding(
            get: { dialValue },
            set: { state.setSlotDistance($0, to: slot, at: idx) }
        )
    }

    private var clubBinding: Binding<String?> {
        Binding(
            get: { state.slotClub(slot, at: idx) },
            set: { if let club = $0 { state.setSlotClub(club, to: slot, at: idx) } }
        )
    }

    private var pinBinding: Binding<String?> {
        Binding(
            get: { state.pinPosition(at: idx) },
            set: { state.setPinPosition($0, at: idx) }
        )
    }

    private func hazardActive(_ tag: HazardTag) -> Bool {
        let (value, modifier) = state.slotValueModifier(slot, at: idx)
        switch tag {
        case .bunker: return value?.hasPrefix("Miss ") == true && modifier == "Bunker"
        case .ob: return value?.hasPrefix("OB ") == true && modifier != "Water"
        case .water: return value?.hasPrefix("OB ") == true && modifier == "Water"
        case .unplayable: return state.entries[idx].penaltyStrokes > 0
        }
    }

    private func resultChip(_ label: String, good: Bool) -> some View {
        Text(label)
            .font(BrutalistType.mono(.semibold, size: 9))
            .kerning(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(good ? BrutalistColor.acc : .clear)
            .foregroundStyle(good ? BrutalistColor.bg : BrutalistColor.fg)
            .overlay(Rectangle().stroke(good ? BrutalistColor.acc : BrutalistColor.fg, lineWidth: 1))
    }
}
