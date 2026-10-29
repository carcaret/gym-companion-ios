import Presentation
import SwiftUI
import ViewModels

/// El tiempo y el descanso. A cero, el tiempo del entreno en grande y debajo «toca para
/// descansar»; descansando, el descanso en grande (verde; cumplido, azul) con su barra hasta 1:30,
/// y el tiempo del entreno debajo.
struct TimeView: View {
    let time: WatchModel.Time
    let isDimmed: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if time.restPhase == .idle {
                big(time.elapsed, color: Theme.gold)
                Text(time.restLabel)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    big(time.rest, color: restColor)
                    Text(time.restLabel)
                        .font(.footnote)
                        .foregroundStyle(restColor)
                        .lineLimit(2)
                }
                if !isDimmed {
                    ProgressView(value: time.restProgress)
                        .tint(restColor)
                }
                HStack(spacing: 4) {
                    Text(time.elapsed)
                        .foregroundStyle(Theme.gold)
                        .monospacedDigit()
                    Text(WatchText.total)
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .opacity(isDimmed ? 0.6 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var restColor: Color {
        time.restPhase == .overdue ? Theme.accentLight : Theme.greenSoft
    }

    private func big(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
