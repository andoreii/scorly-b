import SwiftUI

struct ReviewCardHeader: View {
    let meta: String
    let title: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meta)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(title)
                    .font(BrutalistType.sans(.bold, size: 24))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer(minLength: BrutalistSpacing.m)
            if let trailing {
                Text(trailing)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
    }
}
