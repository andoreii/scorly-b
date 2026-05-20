import SwiftUI

/// Per-putt distance editor. One `DistanceWheel` (in feet) per putt,
/// auto-sized to the current putt count.
public struct PuttDistancesEditor: View {
    private let putts: Int
    @Binding private var distances: [Int?]

    public init(putts: Int, distances: Binding<[Int?]>) {
        self.putts = putts
        _distances = distances
    }

    public var body: some View {
        if putts == 0 {
            Text("No putts on this hole.".uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(Rectangle().stroke(BrutalistColor.hair, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        } else {
            VStack(spacing: 8) {
                ForEach(0..<putts, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("PUTT \(index + 1)")
                                .font(BrutalistType.monoMicro)
                                .kerning(0.8)
                                .foregroundStyle(BrutalistColor.muted)
                            Spacer()
                            Text(distances.indices.contains(index) ? (distances[index].map { "\($0) FT" } ?? "—") : "—")
                                .font(BrutalistType.monoMicro)
                                .kerning(0.8)
                                .foregroundStyle(BrutalistColor.muted)
                        }
                        DistanceWheel(
                            value: putt(at: index),
                            range: 0...80,
                            step: 1,
                            majorEvery: 3,
                            unit: "FT"
                        )
                    }
                }
            }
        }
    }

    private func putt(at index: Int) -> Binding<Int?> {
        Binding<Int?>(
            get: {
                guard distances.indices.contains(index) else { return nil }
                return distances[index]
            },
            set: { newValue in
                while distances.count <= index { distances.append(nil) }
                distances[index] = newValue
            }
        )
    }
}
