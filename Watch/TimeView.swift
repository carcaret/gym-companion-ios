import Presentation
import SwiftUI
import ViewModels

/// El tiempo y el descanso, en una franja que mide lo mismo a cero que descansando, para dejar
/// sitio al ejercicio. A cero, el tiempo del entreno y a su lado «toca para descansar»;
/// descansando, el descanso (verde; cumplido, azul) con el tiempo del entreno a su lado, y debajo
/// su barra hasta 1:30.
struct TimeView: View {
    let time: WatchModel.Time
    let isDimmed: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                if time.restPhase == .idle {
                    big(time.elapsed, color: Theme.gold)
                    Text(time.restLabel)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                } else {
                    big(time.rest, color: restColor)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(time.restLabel)
                            .foregroundStyle(restColor)
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Text(time.elapsed)
                                .foregroundStyle(Theme.gold)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Text(WatchText.total)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .font(.caption2)
            // A cero, la barra está pero no se ve: así la franja no cambia de alto.
            ProgressView(value: time.restProgress)
                .tint(restColor)
                .opacity(time.restPhase == .idle || isDimmed ? 0 : 1)
        }
        .opacity(isDimmed ? Theme.wristDownOpacity : 1)
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
            .layoutPriority(1)
    }
}
