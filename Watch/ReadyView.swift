import Presentation
import SwiftUI
import ViewModels

/// El entreno está en curso en el iPhone y el reloj aún no lo mide: la rutina y «Empezar» (lo
/// normal es que lo haya abierto ya el iPhone al empezar allí).
struct ReadyView: View {
    let ready: WatchModel.Ready
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(ready.routine)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                Text(ready.detail)
                    .foregroundStyle(Theme.textSecondary)
                if let error = ready.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.redSoft)
                }
                Button(action: start) {
                    Label(WatchText.start, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenSoft)
                .disabled(ready.isStarting)
                .accessibilityIdentifier(AccessibilityID.watchStart)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
