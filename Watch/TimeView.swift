import Presentation
import SwiftUI
import ViewModels

/// El tiempo y el descanso, en una franja que mide lo mismo a cero que descansando, para dejar
/// sitio al ejercicio. A cero, el tiempo del entreno y a su lado «toca para descansar»;
/// descansando, el descanso (verde; cumplido, azul) con el tiempo del entreno a su lado, solo el
/// número (decisión del usuario, 2026-10-31: sin «total»; VoiceOver sí lo dice), y debajo su barra
/// hasta 1:30.
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
                        Text(time.elapsed)
                            .foregroundStyle(Theme.gold)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .accessibilityLabel("\(time.elapsed) \(WatchText.total)")
                    }
                }
            }
            .font(.caption2)
            // A cero, la barra está pero no se ve: así la franja no cambia de alto.
            RestBar(progress: time.restProgress, color: restColor)
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

/// La barra del descanso hasta cumplirlo: fina, porque la de `ProgressView` en watchOS mide unos
/// 15 pt y le quitaba sitio al ejercicio (foto del reloj, 2026-10-30).
private struct RestBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        Capsule()
            .fill(color.opacity(0.3))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
    }
}
